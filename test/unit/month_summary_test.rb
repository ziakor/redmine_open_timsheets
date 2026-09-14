# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class MonthSummaryTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :enumerations,
           :projects_trackers, :time_entries

  JULY = Date.new(2026, 7, 1)..Date.new(2026, 7, 31)
  WORKING_DAY = Date.new(2026, 7, 15)
  HOLIDAY     = Date.new(2026, 7, 14)
  SATURDAY    = Date.new(2026, 7, 11)

  # July 2026 has 23 weekdays; Bastille Day removes one, leaving 22 owed.
  EXPECTED_DAYS_IN_JULY = 22

  def setup
    RedmineOpenTimesheets::Holidays.reset_cache!
    Setting.plugin_redmine_open_timesheets = {
      'holiday_region' => 'fr',
      'absence_types' => %w[conges maladie formation autre]
    }
    @user = User.find(2)
    @other = User.find(3)
    travel_to Date.new(2026, 7, 31)
  end

  def teardown
    travel_back
  end

  def log(hours, on:, user: @user)
    TimeEntry.create!(project_id: 1, issue_id: 1, user_id: user.id, author_id: user.id,
                      activity_id: 10, spent_on: on, hours: hours)
  end

  def summary(users: [@user])
    entries = TimeEntry.where(spent_on: JULY, user_id: users.map(&:id)).to_a
    RedmineOpenTimesheets::MonthSummary.new(entries: entries, range: JULY, users: users)
  end

  def test_personal_mode_with_a_single_user
    assert summary.personal?
  end

  def test_collective_mode_with_several_users
    assert_not summary(users: [@user, @other]).personal?
  end

  def test_entries_are_grouped_by_day
    log(3, on: WORKING_DAY)
    log(4, on: WORKING_DAY)
    log(1, on: Date.new(2026, 7, 16))
    assert_equal 2, summary.entries_on(WORKING_DAY).size
  end

  def test_hours_are_summed_per_day_but_never_compared
    log(3, on: WORKING_DAY)
    log(4, on: WORKING_DAY)
    assert_in_delta 7.0, summary.logged_hours_on(WORKING_DAY), 0.001
  end

  def test_any_entry_marks_the_day_declared
    log(1, on: WORKING_DAY)
    assert_equal :logged, summary.status_on(WORKING_DAY)
  end

  def test_a_single_hour_is_enough_there_is_no_threshold
    log(0.5, on: WORKING_DAY)
    assert_equal :logged, summary.status_on(WORKING_DAY)
  end

  def test_an_expected_day_without_entry_is_missing
    assert_equal :missing, summary.status_on(WORKING_DAY)
  end

  def test_weekends_and_holidays_are_off
    assert_equal :off, summary.status_on(SATURDAY)
    assert_equal :off, summary.status_on(HOLIDAY)
  end

  def test_a_declared_day_that_was_not_owed_still_counts_as_declared
    log(4, on: SATURDAY)
    assert_equal :logged, summary.status_on(SATURDAY)
  end

  def test_future_days_are_never_missing
    travel_to Date.new(2026, 7, 10)
    assert_equal :future, summary.status_on(WORKING_DAY)
  end

  def test_today_is_not_in_the_future
    travel_to WORKING_DAY
    assert_equal :missing, summary.status_on(WORKING_DAY)
  end

  def test_collective_mode_scores_nothing
    log(3, on: WORKING_DAY)
    collective = summary(users: [@user, @other])
    assert_equal :unscored, collective.status_on(WORKING_DAY)
    assert_equal 0, collective.expected_days
    assert_equal 0, collective.missing_days
  end

  def test_collective_mode_still_totals_hours
    log(3, on: WORKING_DAY)
    log(4, on: WORKING_DAY, user: @other)
    assert_in_delta 7.0, summary(users: [@user, @other]).total_hours, 0.001
  end

  def test_counters
    log(7, on: WORKING_DAY)
    log(2, on: Date.new(2026, 7, 16))

    assert_equal EXPECTED_DAYS_IN_JULY, summary.expected_days
    assert_equal 2, summary.logged_days
    assert_equal EXPECTED_DAYS_IN_JULY - 2, summary.missing_days
    assert_in_delta 9.0, summary.total_hours, 0.001
  end

  def test_a_full_day_absence_reduces_the_expected_days
    OpenTimesheetsAbsence.create!(user_id: @user.id, absence_type: 'conges',
                                  start_date: Date.new(2026, 7, 13),
                                  end_date: Date.new(2026, 7, 17))
    # 13, 15, 16, 17 July are weekdays; the 14th was already a holiday.
    assert_equal EXPECTED_DAYS_IN_JULY - 4, summary.expected_days
  end

  def test_an_exempt_user_owes_nothing
    OpenTimesheetsExemption.create!(user_id: @user.id)
    assert_equal 0, summary.expected_days
    assert_equal 0, summary.missing_days
  end

  def test_counters_ignore_days_outside_the_counted_range
    # The grid spans whole weeks, so it spills into the neighbouring months.
    # Counting those days would make the banner announce days that belong to
    # June or August.
    grid = Date.new(2026, 6, 29)..Date.new(2026, 8, 2)
    summary = RedmineOpenTimesheets::MonthSummary.new(
      entries: [], range: grid, counted_range: JULY, users: [@user]
    )

    assert_equal EXPECTED_DAYS_IN_JULY, summary.expected_days
    assert_equal EXPECTED_DAYS_IN_JULY, summary.missing_days
  end

  def test_days_outside_the_counted_range_are_never_judged
    # They are only displayed to keep the weeks whole. Marking them missing
    # would contradict the counters, which stop at the month.
    summary = RedmineOpenTimesheets::MonthSummary.new(
      entries: [], range: Date.new(2026, 6, 29)..Date.new(2026, 8, 2),
      counted_range: JULY, users: [@user]
    )

    assert_equal :outside, summary.status_on(Date.new(2026, 6, 29))
    assert_equal :missing, summary.status_on(WORKING_DAY)
  end
end
