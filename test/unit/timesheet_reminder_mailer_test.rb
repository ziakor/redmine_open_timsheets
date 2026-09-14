# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class TimesheetReminderMailerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :enumerations,
           :projects_trackers, :time_entries

  TODAY = Date.new(2026, 7, 17)

  def setup
    RedmineOpenTimesheets::Holidays.reset_cache!
    Setting.plugin_redmine_open_timesheets = {
      'holiday_region' => 'fr',
      'reminder_lookback_days' => '7',
      'absence_types' => %w[conges maladie formation autre]
    }
    Setting.host_name = 'redmine.example.test'
    Setting.protocol = 'http'
    TimeEntry.delete_all
    ActionMailer::Base.deliveries.clear
    travel_to TODAY
  end

  def teardown
    travel_back
  end

  def test_the_mail_lists_the_undeclared_days
    user = User.find(2)
    days = [Date.new(2026, 7, 15), Date.new(2026, 7, 16)]

    mail = TimesheetReminderMailer.reminder(user, days)

    assert_equal [user.mail], mail.to
    assert_match(/2/, mail.subject)
    assert_match(/15/, mail.body.encoded)
    assert_match(/16/, mail.body.encoded)
  end

  def test_the_mail_links_to_the_calendar
    mail = TimesheetReminderMailer.reminder(User.find(2), [Date.new(2026, 7, 15)])

    assert_match(%r{/open_timesheets/calendar}, mail.body.encoded)
  end

  def test_deliver_reminders_queues_one_mail_per_user_behind
    reminded = nil
    perform_enqueued_jobs do
      reminded = TimesheetReminderMailer.deliver_reminders(today: TODAY)
    end

    assert_equal User.active.count, reminded.size
    assert_equal User.active.count, ActionMailer::Base.deliveries.size
  end

  def test_nobody_is_reminded_when_everyone_is_exempt
    User.active.each { |user| OpenTimesheetsExemption.create!(user_id: user.id) }

    reminded = nil
    perform_enqueued_jobs do
      reminded = TimesheetReminderMailer.deliver_reminders(today: TODAY)
    end

    assert_empty reminded
    assert_empty ActionMailer::Base.deliveries
  end
end
