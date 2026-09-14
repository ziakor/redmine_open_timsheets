# frozen_string_literal: true

# Redmine ships no scheduler for plugins, so the reminder is a rake task meant
# to be driven by cron. Example, every working day at 9:00:
#
#   0 9 * * 1-5 cd /opt/redmine && RAILS_ENV=production bundle exec rake redmine:open_timesheets:remind
namespace :redmine do
  namespace :open_timesheets do
    desc 'Email users who have undeclared working days in the recent past'
    task remind: :environment do
      reminded = TimesheetReminderMailer.deliver_reminders
      puts "open_timesheets: #{reminded.size} reminder(s) queued"
      reminded.each { |user| puts "  #{user.login}" }
    end
  end
end
