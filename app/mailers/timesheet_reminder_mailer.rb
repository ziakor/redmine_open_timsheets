# frozen_string_literal: true

# Delivery goes through Redmine's own Mailer: it is always present, already
# configured on the instance, and honours each user's language.
#
# redmine_open_notifications was the intended channel, but its user_notifications
# table requires project_id and issue_id to be NOT NULL. A "you did not declare
# yesterday" reminder has neither, so the coupling would mean inventing a fake
# project and issue. Email until that plugin allows a notification without one.
class TimesheetReminderMailer < Mailer
  def reminder(user, missing_days)
    @user = user
    @missing_days = missing_days
    @calendar_url = url_for(controller: 'timesheet_calendar', action: 'show')

    mail to: user,
         subject: l(:mail_subject_open_timesheets_reminder, count: missing_days.size)
  end

  def self.deliver_reminders(today: User.current.today)
    RedmineOpenTimesheets::Reminder.new(today: today).due.map do |user, missing_days|
      reminder(user, missing_days).deliver_later
      user
    end
  end
end
