# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# rails-controller-testing is not part of Redmine's Gemfile, so `assigns` is
# unavailable. Everything here is asserted on the rendered page or on the
# database, which is the observable behaviour anyway.
class TimesheetCalendarControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :enumerations,
           :projects_trackers, :enabled_modules, :time_entries

  def setup
    RedmineOpenTimesheets::Holidays.reset_cache!
    Setting.plugin_redmine_open_timesheets = {
      'holiday_region' => 'fr',
      'absence_types' => %w[conges maladie formation autre]
    }
    # Deterministic week boundary: unset, Redmine resolves it from the locale,
    # which gives Monday in production (fr) and Sunday in the test environment.
    Setting.start_of_week = '1'
    Setting.rest_api_enabled = '1'
    @request.session[:user_id] = 2
  end

  def test_show_global_renders_a_month_grid
    get :show, params: { year: 2026, month: 7 }

    assert_response :success
    assert_select 'ul.cal'
    assert_select 'ul.cal li.calhead', count: 8
    # July 2026 spans 5 displayed weeks: 1 June 29 to August 2 inclusive.
    assert_select 'ul.cal li.calbody', count: 35
  end

  def test_show_within_a_project
    get :show, params: { project_id: 1, year: 2026, month: 7 }

    assert_response :success
    assert_select 'ul.cal'
  end

  def test_displayed_month_follows_the_parameters
    get :show, params: { year: 2026, month: 7 }

    assert_select '.ots-month[data-year=?][data-month=?]', '2026', '7'
  end

  def test_invalid_month_falls_back_to_today
    get :show, params: { year: 2026, month: 47 }

    assert_response :success
    assert_select '.ots-month[data-month=?]', User.current.today.month.to_s
  end

  def test_invalid_year_falls_back_to_today
    get :show, params: { year: 1492, month: 7 }

    assert_response :success
    assert_select '.ots-month[data-year=?]', User.current.today.year.to_s
  end

  def test_no_params_shows_the_current_month
    get :show

    assert_response :success
    assert_select '.ots-month[data-year=?][data-month=?]',
                  User.current.today.year.to_s, User.current.today.month.to_s
  end

  def test_user_filter_defaults_to_the_current_user
    get :show, params: { year: 2026, month: 7 }

    assert_select '.ots-calendar[data-mode=?]', 'personal'
  end

  def test_an_explicit_multi_user_filter_switches_to_collective_mode
    get :show, params: { year: 2026, month: 7, set_filter: 1,
                         f: ['user_id'], op: { 'user_id' => '=' },
                         v: { 'user_id' => %w[2 3] } }

    assert_response :success
    assert_select '.ots-calendar[data-mode=?]', 'collective'
  end

  def test_an_empty_month_stays_in_personal_mode
    # Regression guard: deriving the scope from the returned entries would
    # classify an empty month as collective, hiding the very gaps the calendar
    # exists to reveal.
    get :show, params: { year: 2019, month: 2 }

    assert_response :success
    assert_select '.ots-calendar[data-mode=?]', 'personal'
  end

  def test_requires_view_time_entries_permission
    Role.find(1).remove_permission!(:view_time_entries)

    get :show, params: { project_id: 1, year: 2026, month: 7 }

    assert_response :forbidden
  end

  def test_the_three_tabs_are_rendered_with_calendar_selected
    get :show, params: { project_id: 1, year: 2026, month: 7 }

    assert_select 'div.ots-tabs ul li', count: 3
    assert_select 'div.ots-tabs ul li a.selected', text: I18n.t(:label_open_timesheets_calendar)
  end

  def log(hours, on:, user_id: 2)
    TimeEntry.create!(project_id: 1, issue_id: 1, user_id: user_id, author_id: user_id,
                      activity_id: 10, spent_on: on, hours: hours)
  end

  def test_an_expected_day_without_entry_is_marked_missing
    get :show, params: { year: 2026, month: 7 }

    assert_select 'li.calbody.ots-missing', minimum: 1
  end

  def test_a_day_with_an_entry_is_marked_logged
    log(3, on: Date.new(2026, 7, 15))

    get :show, params: { year: 2026, month: 7 }

    assert_select 'li.calbody.ots-logged', count: 1
  end

  def test_there_is_no_hour_threshold
    log(0.5, on: Date.new(2026, 7, 15))

    get :show, params: { year: 2026, month: 7 }

    assert_select 'li.calbody.ots-logged', count: 1
    assert_select 'li.calbody.ots-partial', count: 0
  end

  def test_weekends_and_holidays_are_never_marked_missing
    get :show, params: { year: 2026, month: 7 }

    assert_select 'li.calbody.nwday.ots-missing', count: 0
    assert_select 'li.calbody.ots-off', minimum: 1
  end

  def test_entries_are_listed_in_their_day_cell
    entry = log(3, on: Date.new(2026, 7, 15))

    get :show, params: { year: 2026, month: 7 }

    assert_select 'li.calbody div.ots-entry a[href=?]', "/issues/#{entry.issue_id}"
  end

  def test_an_entry_shows_its_activity
    log(3, on: Date.new(2026, 7, 15))

    get :show, params: { year: 2026, month: 7 }

    assert_select 'div.ots-entry .ots-entry-activity', text: TimeEntryActivity.find(10).name
  end

  def test_the_project_is_shown_on_the_global_screen
    log(3, on: Date.new(2026, 7, 15))

    get :show, params: { year: 2026, month: 7 }

    assert_select 'div.ots-entry .ots-entry-project', text: Project.find(1).name
  end

  def test_the_project_is_hidden_inside_a_project
    log(3, on: Date.new(2026, 7, 15))

    get :show, params: { project_id: 1, year: 2026, month: 7 }

    assert_select 'div.ots-entry', minimum: 1
    assert_select 'div.ots-entry .ots-entry-project', count: 0
  end

  def test_a_holiday_shows_its_name
    get :show, params: { year: 2026, month: 7 }

    assert_select 'li.calbody p.ots-note', text: I18n.t(:holiday_bastille_day)
  end

  def test_an_absence_shows_its_reason
    OpenTimesheetsAbsence.create!(user_id: 2, absence_type: 'conges',
                                  start_date: Date.new(2026, 7, 20),
                                  end_date: Date.new(2026, 7, 24))

    get :show, params: { year: 2026, month: 7 }

    assert_select 'li.calbody p.ots-note', text: I18n.t(:absence_type_conges), minimum: 1
  end

  def test_summary_counts_missing_days_in_personal_mode
    # July 2026 has 23 weekdays, Bastille Day removes one, nothing is logged.
    get :show, params: { year: 2026, month: 7 }

    assert_select '.ots-summary .ots-missing-days', text: /22/
    # No ratio: the numerator would count days the denominator excludes, such
    # as a day worked on a public holiday.
    assert_select '.ots-summary .ots-declared-days'
    assert_select '.ots-summary .ots-declared-days', text: %r{/}, count: 0
  end

  def test_summary_hides_day_counters_in_collective_mode
    get :show, params: { year: 2026, month: 7, set_filter: 1,
                         f: ['user_id'], op: { 'user_id' => '=' },
                         v: { 'user_id' => %w[2 3] } }

    assert_select '.ots-summary .ots-missing-days', count: 0
    assert_select '.ots-summary .ots-collective-notice', count: 1
  end

  def test_summary_always_shows_the_hour_total
    log(3, on: Date.new(2026, 7, 15))
    log(4, on: Date.new(2026, 7, 16))

    get :show, params: { year: 2026, month: 7 }

    assert_select '.ots-summary .ots-hours', text: /7/
  end

  def test_future_days_are_marked_and_never_missing
    get :show, params: { year: 2099, month: 7 }

    assert_select 'li.calbody.ots-future', minimum: 1
    assert_select 'li.calbody.ots-missing', count: 0
  end

  def test_week_mode_shows_seven_cells
    get :show, params: { date: '2026-07-15', period: 'week' }

    assert_response :success
    assert_select 'ul.cal li.calbody', count: 7
    assert_select '.ots-month[data-period=?]', 'week'
  end

  def test_month_mode_is_the_default
    get :show, params: { date: '2026-07-15' }

    assert_select 'ul.cal li.calbody', count: 35
    assert_select '.ots-month[data-period=?]', 'month'
  end

  def test_week_counters_cover_the_week_only
    # 13 to 19 July 2026: five weekdays, of which the 14th is Bastille Day,
    # leaving four owed days and no entry.
    get :show, params: { date: '2026-07-15', period: 'week' }

    assert_select '.ots-summary .ots-missing-days', text: /4/
    assert_select 'li.calbody.ots-outside', count: 0
  end

  def test_week_navigation_moves_by_seven_days
    get :show, params: { date: '2026-07-15', period: 'week' }

    assert_select 'a.ots-next[href*=?]', '2026-07-22'
    assert_select 'a.ots-prev[href*=?]', '2026-07-08'
  end

  def test_month_navigation_moves_by_one_month
    get :show, params: { date: '2026-07-15' }

    assert_select 'a.ots-next[href*=?]', '2026-08-15'
    assert_select 'a.ots-prev[href*=?]', '2026-06-15'
  end

  def test_the_period_switch_keeps_the_reference_date
    get :show, params: { date: '2026-07-15', period: 'week' }

    assert_select 'a.ots-period-month[href*=?]', '2026-07-15'
    assert_select 'a.ots-period-week.selected'
  end

  def test_an_unparseable_date_falls_back_to_today
    get :show, params: { date: 'pas-une-date' }

    assert_response :success
    assert_select '.ots-month[data-year=?][data-month=?]',
                  User.current.today.year.to_s, User.current.today.month.to_s
  end

  def test_a_week_straddling_two_months_greys_nothing
    # Week 36 of 2026 runs from Monday 31 August to Sunday 6 September. The
    # core would mark the 31st as other-month and grey it, although it belongs
    # to the displayed week as much as the rest.
    get :show, params: { date: '2026-09-02', period: 'week' }

    assert_select 'ul.cal li.calbody', count: 7
    assert_select 'ul.cal li.calbody.other-month', count: 0
  end

  def test_a_month_grid_still_greys_the_neighbouring_days
    get :show, params: { date: '2026-07-15' }

    assert_select 'ul.cal li.calbody.other-month', count: 4
  end

  def test_json_payload
    log(3, on: Date.new(2026, 7, 15))

    get :show, params: { date: '2026-07-15', format: 'json', key: User.find(2).api_key }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 'month', payload['period']
    assert_equal '2026-07-01', payload['from']
    assert_equal '2026-07-31', payload['to']
    assert payload['personal']
    assert_equal 1, payload['declared_days']
    assert_equal 22, payload['expected_days']
    assert_equal 21, payload['missing_days']
    assert_in_delta 3.0, payload['hours'], 0.001
    assert_equal 31, payload['days'].size
  end

  def test_json_days_carry_their_status_and_entries
    entry = log(3, on: Date.new(2026, 7, 15))

    get :show, params: { date: '2026-07-15', format: 'json', key: User.find(2).api_key }

    days = JSON.parse(response.body)['days'].index_by { |day| day['date'] }
    assert_equal 'logged', days['2026-07-15']['status']
    assert_equal entry.issue_id, days['2026-07-15']['entries'].first['issue_id']
    assert_equal 'off', days['2026-07-14']['status']
    assert_equal 'missing', days['2026-07-16']['status']
  end

  def test_json_in_week_mode_covers_the_week_only
    get :show, params: { date: '2026-07-15', period: 'week', format: 'json', key: User.find(2).api_key }

    payload = JSON.parse(response.body)
    assert_equal 'week', payload['period']
    assert_equal 7, payload['days'].size
    assert_equal '2026-07-13', payload['from']
  end

  def test_csv_export_has_one_row_per_day
    log(3, on: Date.new(2026, 7, 15))

    get :show, params: { date: '2026-07-15', format: 'csv' }

    assert_response :success
    assert_includes response.media_type, 'text/csv'
    lines = response.body.split("\n")
    assert_equal 32, lines.size
    assert_match(/2026-07-15/, response.body)
    assert_match(/logged/, response.body)
  end

  def test_csv_filename_carries_the_period
    get :show, params: { date: '2026-07-15', format: 'csv' }

    assert_match(/open_timesheets_2026-07\.csv/, response.headers['Content-Disposition'])
  end

  def test_json_separates_owed_days_from_owed_days_to_date
    # Travelled to 31 July 2026 by default, so the whole month is past and the
    # two counters coincide.
    get :show, params: { date: '2026-07-15', format: 'json', key: User.find(2).api_key }

    payload = JSON.parse(response.body)
    assert_equal 22, payload['expected_days']
    assert_equal 22, payload['expected_days_to_date']
  end

  def test_json_owed_days_to_date_stops_at_today_in_a_month_in_progress
    travel_to Date.new(2026, 7, 8)

    get :show, params: { date: '2026-07-15', format: 'json', key: User.find(2).api_key }

    payload = JSON.parse(response.body)
    assert_equal 22, payload['expected_days']
    # 1 to 8 July: six weekdays, none a public holiday.
    assert_equal 6, payload['expected_days_to_date']
    assert_equal 6, payload['missing_days']
  ensure
    travel_back
  end
end
