# frozen_string_literal: true

module RedmineOpenTimesheets
  # Reading a period out of the request is one piece of knowledge, and both the
  # calendar and the team view need it. Defined once so the two cannot drift.
  #
  # Accepts an ISO date, or the year/month/day triplet the month navigation
  # produces. Falls back to today on anything unparseable, mirroring
  # CalendarsController#show.
  module PeriodParams
    private

    # Both controllers open on the same four values. Assigned here so the two
    # cannot drift, and so neither action carries the boilerplate.
    def prepare_period
      @period = requested_period
      @date = requested_date
      @calendar = Redmine::Helpers::Calendar.new(@date, current_language, @period)
      @range = counted_period(@calendar, @date, @period)
    end

    def requested_period
      params[:period].to_s == 'week' ? :week : :month
    end

    def requested_date
      iso_date || triplet_date || User.current.today
    end

    # In month mode the grid spans whole weeks and spills into the neighbouring
    # months, so the counters must stay on the month itself or the banner
    # announces days belonging to another one. In week mode the grid is exactly
    # the period, so there is nothing to trim.
    def counted_period(calendar, date, period)
      return calendar.startdt..calendar.enddt if period == :week

      month_range(date)
    end

    def month_range(date)
      Date.civil(date.year, date.month, 1)..Date.civil(date.year, date.month, -1)
    end

    def iso_date
      return nil if params[:date].blank?

      Date.iso8601(params[:date].to_s)
    rescue Date::Error
      nil
    end

    def triplet_date
      return nil if params[:year].blank? && params[:month].blank?

      today = User.current.today
      Date.civil(param_within(:year, 1901..9999, today.year),
                 param_within(:month, 1..12, today.month),
                 param_within(:day, 1..31, 1))
    rescue Date::Error
      # Reachable on a real date that does not exist, such as 31 February.
      User.current.today
    end

    def param_within(key, range, default)
      value = params[key].to_i
      range.cover?(value) ? value : default
    end
  end
end
