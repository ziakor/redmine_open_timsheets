# frozen_string_literal: true

module RedmineOpenTimesheets
  # Finds who has undeclared working days in the recent past.
  #
  # The production data showed entries logged up to 19 days late. A calendar
  # reveals the gap only to someone who opens it; a reminder goes looking.
  class Reminder
    DEFAULT_LOOKBACK_DAYS = 7

    def initialize(today: User.current.today, lookback_days: nil)
      @today = today
      @lookback_days = (lookback_days || setting_lookback_days).to_i
    end

    # The window stops yesterday: nobody owes today's declaration yet.
    def range
      (@today - @lookback_days)..(@today - 1)
    end

    # [[user, [Date, ...]], ...], only for users who actually owe something.
    def due
      users = OpenTimesheetsExemption.tracked_users
      entries = TimeEntry.where(spent_on: range, user_id: users.map(&:id)).to_a
      by_user = entries.group_by(&:user_id)

      users.filter_map do |user|
        missing = missing_days_for(user, by_user[user.id] || [])
        [user, missing] unless missing.empty?
      end
    end

    private

    def missing_days_for(user, entries)
      summary = MonthSummary.new(entries: entries, range: range, users: [user])
      range.select { |date| summary.status_on(date) == :missing }
    end

    def setting_lookback_days
      value = Setting.plugin_redmine_open_timesheets['reminder_lookback_days']
      value.presence || DEFAULT_LOOKBACK_DAYS
    end
  end
end
