# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ScheduleTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses

  JULY = Date.new(2026, 7, 1)..Date.new(2026, 7, 31)
  WORKING_DAY = Date.new(2026, 7, 15)  # ordinary Wednesday
  SATURDAY    = Date.new(2026, 7, 11)
  SUNDAY      = Date.new(2026, 7, 12)
  HOLIDAY     = Date.new(2026, 7, 14)  # Bastille Day, a Tuesday

  def setup
    RedmineOpenTimesheets::Holidays.reset_cache!
    Setting.plugin_redmine_open_timesheets = {
      'holiday_region' => 'fr',
      'absence_types' => %w[conges maladie formation autre]
    }
    @user = User.find(2)
  end

  def schedule(user = @user)
    RedmineOpenTimesheets::Schedule.new(user, JULY)
  end

  def test_an_ordinary_weekday_is_expected
    assert schedule.expected?(WORKING_DAY)
  end

  def test_weekends_are_not_expected
    assert_not schedule.expected?(SATURDAY)
    assert_not schedule.expected?(SUNDAY)
  end

  def test_public_holidays_are_not_expected
    assert_not schedule.expected?(HOLIDAY)
  end

  def test_an_exempt_user_never_owes_a_day
    OpenTimesheetsExemption.create!(user_id: @user.id)
    assert_not schedule.expected?(WORKING_DAY)
  end

  def test_a_full_day_absence_removes_the_day
    OpenTimesheetsAbsence.create!(user_id: @user.id, absence_type: 'conges',
                                  start_date: Date.new(2026, 7, 13),
                                  end_date: Date.new(2026, 7, 17))
    assert_not schedule.expected?(WORKING_DAY)
  end

  def test_a_half_day_absence_keeps_the_day_expected
    # The other half was worked, so it still has to be declared.
    OpenTimesheetsAbsence.create!(user_id: @user.id, absence_type: 'formation',
                                  start_date: WORKING_DAY, end_date: WORKING_DAY,
                                  half_day: true)
    assert schedule.expected?(WORKING_DAY)
  end

  def test_an_absence_of_another_user_has_no_effect
    OpenTimesheetsAbsence.create!(user_id: 3, absence_type: 'conges',
                                  start_date: WORKING_DAY, end_date: WORKING_DAY)
    assert schedule.expected?(WORKING_DAY)
  end

  def test_exemption_takes_precedence_over_everything
    OpenTimesheetsExemption.create!(user_id: @user.id)
    assert_not schedule.expected?(WORKING_DAY)
    assert schedule.exempt?
  end

  def test_non_working_week_days_setting_is_honoured
    with_settings non_working_week_days: %w[3] do
      assert_not schedule.expected?(WORKING_DAY)
      assert schedule.expected?(SATURDAY)
    end
  end

  def test_holiday_name_is_exposed
    assert_equal :holiday_bastille_day, schedule.holiday_name(HOLIDAY)
    assert_nil schedule.holiday_name(WORKING_DAY)
  end

  def test_absence_on_is_exposed
    absence = OpenTimesheetsAbsence.create!(user_id: @user.id, absence_type: 'conges',
                                            start_date: WORKING_DAY, end_date: WORKING_DAY)
    assert_equal absence, schedule.absence_on(WORKING_DAY)
    assert_nil schedule.absence_on(SATURDAY)
  end
end
