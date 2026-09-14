# frozen_string_literal: true

module RedmineOpenTimesheets
  # Per-person completion over a period, for the team view.
  #
  # Reuses MonthSummary rather than recomputing the rules: what a day owes, and
  # what counts as declared, must be answered the same way here and in the
  # calendar. One definition, two readers.
  class TeamSummary
    Row = Struct.new(:user, :declared_days, :expected_days, :missing_days, :hours,
                     keyword_init: true) do
      # Nil rather than 100 when nothing is owed: a month of leave has no
      # completion rate, and showing 100 % would read as an achievement.
      def completion_percent
        return nil if expected_days.zero?

        ((expected_days - missing_days) * 100.0 / expected_days).round
      end
    end

    def initialize(users:, range:, entries:, today: nil)
      @users = users
      @range = range
      @entries_by_user = entries.group_by(&:user_id)
      @today = today || User.current.today
    end

    # Nobody can be late on a day that has not happened. Counting future days
    # as owed would show a month barely started as almost complete, which is
    # the same mistake as a ratio mixing two different sets.
    def counted_range
      @counted_range ||= @range.first..[@range.last, @today].min
    end

    # Worst first: the screen exists to spot who is behind, not to list names.
    def rows
      @rows ||= @users.map { |user| build_row(user) }
                      .sort_by { |row| [-row.missing_days, row.user.login.to_s] }
    end

    def total_missing_days
      rows.sum(&:missing_days)
    end

    def users_with_missing_days
      rows.count { |row| row.missing_days.positive? }
    end

    private

    def build_row(user)
      summary = MonthSummary.new(entries: @entries_by_user[user.id] || [],
                                 range: counted_range, users: [user])
      # declared_days counts owed days that were declared, not every day with an
      # entry. A table whose columns do not add up is read as wrong, and days
      # worked outside the owed ones say nothing about lateness. The hours
      # column still totals everything.
      expected = summary.expected_days
      missing = summary.missing_days
      Row.new(user: user,
              declared_days: expected - missing,
              expected_days: expected,
              missing_days: missing,
              hours: summary.total_hours)
    end
  end
end
