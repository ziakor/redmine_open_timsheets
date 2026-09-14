# frozen_string_literal: true

module RedmineOpenTimesheets
  # Serialisation of a calendar period, for the JSON API and the CSV export.
  #
  # Kept out of MonthSummary: how the period is computed and how it is
  # published are two concerns, and only one of them is a public contract.
  class CalendarPayload
    def initialize(summary:, range:, period:)
      @summary = summary
      @range = range
      @period = period
    end

    def to_hash
      {
        period: @period.to_s,
        from: @range.first.iso8601,
        to: @range.last.iso8601,
        personal: @summary.personal?
      }.merge(counters).merge(days: days)
    end

    # Four counters over three different sets, so each one says which set it
    # covers. declared_days counts every day carrying an entry, including days
    # that were not owed; expected_days covers the whole period, future
    # included; expected_days_to_date and missing_days stop at today. A ratio
    # is only meaningful between the last two.
    def counters
      {
        declared_days: @summary.logged_days,
        expected_days: @summary.expected_days,
        expected_days_to_date: @summary.expected_days_to_date,
        missing_days: @summary.missing_days,
        hours: @summary.total_hours.round(2)
      }
    end

    # One row per day rather than per entry: Redmine already exports the
    # entries themselves. What this adds is the status of each day.
    def csv_rows
      @range.map do |date|
        [date.iso8601,
         Date::DAYNAMES[date.wday],
         @summary.status_on(date).to_s,
         @summary.logged_hours_on(date).round(2),
         @summary.entries_on(date).size]
      end
    end

    def csv_headers
      %i[date day status hours entries].map { |key| l(:"field_open_timesheets_csv_#{key}") }
    end

    private

    def l(*args)
      ::I18n.t(*args)
    end

    def days
      @range.map do |date|
        {
          date: date.iso8601,
          status: @summary.status_on(date).to_s,
          hours: @summary.logged_hours_on(date).round(2),
          entries: @summary.entries_on(date).map { |entry| entry_hash(entry) }
        }
      end
    end

    def entry_hash(entry)
      {
        id: entry.id,
        hours: entry.hours.to_f,
        issue_id: entry.issue_id,
        project: entry.project&.name,
        activity: entry.activity&.name,
        user_id: entry.user_id,
        comments: entry.comments
      }
    end
  end
end
