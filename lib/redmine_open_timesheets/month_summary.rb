# frozen_string_literal: true

module RedmineOpenTimesheets
  # Aggregates time entries over a date range for calendar rendering.
  #
  # Tracking is day-based: a day is declared or it is not. Hours are summed for
  # display only and are never compared to a target.
  #
  # Completeness only makes sense per person, so it is scored in personal mode
  # only. Summing the days owed by several users inside one cell would produce
  # an unreadable figure.
  class MonthSummary
    # `range` is what the grid displays, which spills into the neighbouring
    # months so that weeks stay whole. `counted_range` is what the counters
    # cover. Keeping them apart stops the banner from announcing days that
    # belong to another month.
    def initialize(entries:, range:, users:, counted_range: nil)
      @range = range
      @counted_range = counted_range || range
      @users = Array(users)
      @entries_by_day = entries.group_by(&:spent_on)
      @schedule = (Schedule.new(@users.first, range) if personal?)
    end

    def personal?
      @users.size == 1
    end

    def entries_on(date)
      @entries_by_day[date] || []
    end

    def logged_hours_on(date)
      entries_on(date).sum { |entry| entry.hours.to_f }
    end

    def declared_on?(date)
      entries_on(date).any?
    end

    def expected_on?(date)
      return false unless personal?

      @schedule.expected?(date)
    end

    # A declared day is declared, whatever else it was: working a Saturday
    # still shows as declared rather than as a day off.
    def counted?(date)
      @counted_range.cover?(date)
    end

    # Days shown only to keep the weeks whole are never judged: marking them
    # would contradict the counters, which stop at the month.
    def status_on(date)
      return :outside unless counted?(date)
      return :unscored unless personal?
      return :logged if declared_on?(date)
      return :future if date > User.current.today
      return :off unless expected_on?(date)

      :missing
    end

    def holiday_name(date)
      return nil unless personal?

      @schedule.holiday_name(date)
    end

    def absence_on(date)
      return nil unless personal?

      @schedule.absence_on(date)
    end

    def expected_days
      @counted_range.count { |date| expected_on?(date) }
    end

    def logged_days
      @counted_range.count { |date| declared_on?(date) }
    end

    # Owed days that have already happened. Kept apart from expected_days so no
    # caller can divide a count of past days by a count that includes the
    # future, which would read a month barely started as almost complete.
    def expected_days_to_date
      today = User.current.today
      @counted_range.count { |date| date <= today && expected_on?(date) }
    end

    def missing_days
      @counted_range.count { |date| status_on(date) == :missing }
    end

    # Informative only. Kept because the hours still say how the day was split
    # between issues, which matters for rebilling, not for compliance.
    def total_hours
      @counted_range.sum { |date| logged_hours_on(date) }
    end
  end
end
