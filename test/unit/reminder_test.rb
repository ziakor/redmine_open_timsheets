# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ReminderTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :enumerations,
           :projects_trackers, :time_entries

  # Friday 17 July 2026. The window of the seven previous days runs from the
  # 10th to the 16th: five weekdays, none of them a public holiday except the
  # 14th, so four owed days.
  TODAY = Date.new(2026, 7, 17)
  OWED_DAYS_IN_WINDOW = 4

  def setup
    RedmineOpenTimesheets::Holidays.reset_cache!
    Setting.plugin_redmine_open_timesheets = {
      'holiday_region' => 'fr',
      'reminder_lookback_days' => '7',
      'absence_types' => %w[conges maladie formation autre]
    }
    TimeEntry.delete_all
    travel_to TODAY
  end

  def teardown
    travel_back
  end

  def reminder(**options)
    RedmineOpenTimesheets::Reminder.new(today: TODAY, **options)
  end

  def log(on:, user_id:)
    TimeEntry.create!(project_id: 1, issue_id: 1, user_id: user_id, author_id: user_id,
                      activity_id: 10, spent_on: on, hours: 7)
  end

  def test_the_window_stops_yesterday
    assert_equal Date.new(2026, 7, 10), reminder.range.first
    assert_equal Date.new(2026, 7, 16), reminder.range.last
  end

  def test_today_is_never_owed
    assert_not reminder.range.cover?(TODAY)
  end

  def test_everyone_tracked_is_due_when_nothing_is_declared
    assert_equal User.active.count, reminder.due.size
  end

  def test_the_owed_days_are_listed
    _user, missing = reminder.due.first
    assert_equal OWED_DAYS_IN_WINDOW, missing.size
    assert_includes missing, Date.new(2026, 7, 15)
    assert_not_includes missing, Date.new(2026, 7, 14) # Bastille Day
    assert_not_includes missing, Date.new(2026, 7, 11) # Saturday
  end

  def test_a_declared_day_drops_out_of_the_list
    log(on: Date.new(2026, 7, 15), user_id: 2)

    _user, missing = reminder.due.find { |user, _| user.id == 2 }
    assert_equal OWED_DAYS_IN_WINDOW - 1, missing.size
    assert_not_includes missing, Date.new(2026, 7, 15)
  end

  def test_a_user_who_declared_everything_is_not_due
    [10, 13, 15, 16].each { |day| log(on: Date.new(2026, 7, day), user_id: 2) }

    assert_nil(reminder.due.find { |user, _| user.id == 2 })
  end

  def test_an_exempt_user_is_never_due
    OpenTimesheetsExemption.create!(user_id: 2)

    assert_nil(reminder.due.find { |user, _| user.id == 2 })
  end

  def test_an_absence_removes_the_day
    OpenTimesheetsAbsence.create!(user_id: 2, absence_type: 'conges',
                                  start_date: Date.new(2026, 7, 13),
                                  end_date: Date.new(2026, 7, 16))

    _user, missing = reminder.due.find { |user, _| user.id == 2 }
    assert_equal 1, missing.size
    assert_equal Date.new(2026, 7, 10), missing.first
  end

  def test_the_window_length_is_configurable
    assert_equal Date.new(2026, 7, 16), reminder(lookback_days: 1).range.first
  end

  def test_the_window_length_follows_the_setting
    with_plugin_setting('reminder_lookback_days', '2') do
      assert_equal Date.new(2026, 7, 15), RedmineOpenTimesheets::Reminder.new(today: TODAY).range.first
    end
  end

  private

  def with_plugin_setting(key, value)
    settings = Setting.plugin_redmine_open_timesheets.dup
    Setting.plugin_redmine_open_timesheets = settings.merge(key => value)
    yield
  ensure
    Setting.plugin_redmine_open_timesheets = settings
  end
end
