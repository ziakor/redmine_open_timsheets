# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class TimesheetTeamControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :enumerations,
           :projects_trackers, :enabled_modules, :time_entries

  def setup
    RedmineOpenTimesheets::Holidays.reset_cache!
    Setting.plugin_redmine_open_timesheets = {
      'holiday_region' => 'fr',
      'absence_types' => %w[conges maladie formation autre]
    }
    travel_to Date.new(2026, 7, 31)
  end

  def teardown
    travel_back
  end

  def log(hours, on:, user_id:)
    TimeEntry.create!(project_id: 1, issue_id: 1, user_id: user_id, author_id: user_id,
                      activity_id: 10, spent_on: on, hours: hours)
  end

  def test_an_ordinary_user_is_denied
    @request.session[:user_id] = 2

    get :show, params: { date: '2026-07-15' }

    assert_response :forbidden
  end

  def test_anonymous_is_redirected_to_login
    get :show, params: { date: '2026-07-15' }

    assert_response :found
  end

  def test_an_administrator_is_allowed
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15' }

    assert_response :success
    assert_select 'table.list.ots-team'
  end

  def test_a_designated_user_is_allowed
    OpenTimesheetsTeamViewer.create!(user_id: 2)
    @request.session[:user_id] = 2

    get :show, params: { date: '2026-07-15' }

    assert_response :success
  end

  def test_exempt_users_are_not_listed
    OpenTimesheetsExemption.create!(user_id: 2)
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15' }

    assert_select 'table.ots-team tbody tr', count: User.active.count - 1
  end

  def test_rows_report_missing_days
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15' }

    # Nobody logged anything in July 2026, so every tracked user owes 22 days.
    assert_select 'table.ots-team tbody tr td.ots-team-missing-cell', text: '22', minimum: 1
  end

  def test_a_declared_day_reduces_the_missing_count
    log(7, on: Date.new(2026, 7, 15), user_id: 2)
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15' }

    assert_select 'table.ots-team tbody tr td.ots-team-missing-cell', text: '21', count: 1
  end

  def test_the_banner_counts_people_behind
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15' }

    assert_select '.ots-summary .ots-team-total', text: /#{User.active.count}/
  end

  def test_week_mode_narrows_the_period
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15', period: 'week' }

    assert_response :success
    # 13 to 19 July: five weekdays minus Bastille Day, so four owed.
    assert_select 'table.ots-team tbody tr td.ots-team-missing-cell', text: '4', minimum: 1
  end

  def test_csv_export
    log(7, on: Date.new(2026, 7, 15), user_id: 2)
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15', format: 'csv' }

    assert_response :success
    assert_includes response.media_type, 'text/csv'
    lines = response.body.split("\n")
    assert_equal User.active.count + 1, lines.size
    assert_match(/open_timesheets_team_2026-07\.csv/, response.headers['Content-Disposition'])
  end

  def test_csv_export_is_denied_to_an_ordinary_user
    @request.session[:user_id] = 2

    get :show, params: { date: '2026-07-15', format: 'csv' }

    assert_response :forbidden
  end

  def test_future_days_are_not_counted_as_owed
    # Travelled to 31 July 2026, so the whole month is in the past and the
    # 22 owed days stand.
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15' }

    assert_select 'table.ots-team tbody tr td.ots-team-missing-cell', text: '22', minimum: 1
  end

  def test_a_month_in_progress_only_owes_up_to_today
    travel_to Date.new(2026, 7, 8)
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15' }

    # 1 to 8 July 2026: six weekdays, none of them a public holiday.
    assert_select 'table.ots-team tbody tr td.ots-team-missing-cell', text: '6', minimum: 1
  end

  def test_being_up_to_date_in_a_month_in_progress_reads_as_complete
    travel_to Date.new(2026, 7, 8)
    [1, 2, 3, 6, 7, 8].each { |day| log(7, on: Date.new(2026, 7, day), user_id: 2) }
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15' }

    assert_select 'table.ots-team tbody tr', text: /100 %/, count: 1
  end

  def test_the_columns_add_up_on_every_row_even_when_a_holiday_was_worked
    # 14 July 2026 is a public holiday, so it is never owed. Working it must
    # not make declared + missing differ from owed on any row.
    log(7, on: Date.new(2026, 7, 14), user_id: 2)
    log(7, on: Date.new(2026, 7, 15), user_id: 2)
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15' }

    rows = css_select('table.ots-team tbody tr')
    assert_equal User.active.count, rows.size

    rows.each do |row|
      cells = row.css('td').map { |cell| cell.text.strip }
      missing = cells[1].to_i
      declared = cells[2].to_i
      expected = cells[3].to_i

      assert_equal expected, declared + missing,
                   "declared #{declared} + missing #{missing} should equal owed #{expected}"
      assert_equal 22, expected
    end
  end

  def test_a_day_worked_outside_the_owed_ones_does_not_count_as_declared
    log(7, on: Date.new(2026, 7, 14), user_id: 2) # Bastille Day
    @request.session[:user_id] = 1

    get :show, params: { date: '2026-07-15' }

    # Every row still owes its 22 days in full: the holiday was never owed.
    assert_select('table.ots-team tbody tr td.ots-team-missing-cell',
                  text: '22', count: User.active.count)
  end
end
