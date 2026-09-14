# frozen_string_literal: true

module RedmineOpenTimesheets
  # French public holidays, computed rather than stored.
  # No external dependency: eleven bounded, stable dates do not justify adding
  # a gem to the Gemfile of a production Redmine.
  module Holidays
    FIXED = {
      [1, 1] => :holiday_new_year,
      [5, 1] => :holiday_labour_day,
      [5, 8] => :holiday_victory_1945,
      [7, 14] => :holiday_bastille_day,
      [8, 15] => :holiday_assumption,
      [11, 1] => :holiday_all_saints,
      [11, 11] => :holiday_armistice,
      [12, 25] => :holiday_christmas
    }.freeze

    REGIONS = %w[fr fr_alsace_moselle].freeze
    DEFAULT_REGION = 'fr'

    class << self
      def for_year(year, region: DEFAULT_REGION)
        region = DEFAULT_REGION unless REGIONS.include?(region.to_s)
        @cache ||= {}
        @cache[[year, region]] ||= build(year, region)
      end

      def holiday?(date, region: DEFAULT_REGION)
        for_year(date.year, region: region).key?(date)
      end

      # Anonymous Gregorian algorithm (Meeus / Jones / Butcher). The formula is
      # one indivisible unit: splitting it into helpers would name nothing and
      # would hide the algorithm behind arbitrary boundaries.
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def easter(year)
        a = year % 19
        b, c = year.divmod(100)
        d, e = b.divmod(4)
        f = (b + 8) / 25
        g = (b - f + 1) / 3
        h = ((19 * a) + b - d - g + 15) % 30
        i, k = c.divmod(4)
        l = (32 + (2 * e) + (2 * i) - h - k) % 7
        m = (a + (11 * h) + (22 * l)) / 451
        month = (h + l - (7 * m) + 114) / 31
        day = ((h + l - (7 * m) + 114) % 31) + 1
        Date.new(year, month, day)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def reset_cache!
        @cache = {}
      end

      private

      def build(year, region)
        days = fixed_holidays(year)
        days.merge!(movable_holidays(easter(year)))
        days.merge!(regional_holidays(year, region))
        days.freeze
      end

      def fixed_holidays(year)
        FIXED.each_with_object({}) do |((month, day), key), days|
          days[Date.new(year, month, day)] = key
        end
      end

      def movable_holidays(easter_day)
        {
          easter_day + 1 => :holiday_easter_monday,
          easter_day + 39 => :holiday_ascension,
          easter_day + 50 => :holiday_whit_monday
        }
      end

      def regional_holidays(year, region)
        return {} unless region == 'fr_alsace_moselle'

        {
          easter(year) - 2 => :holiday_good_friday,
          Date.new(year, 12, 26) => :holiday_st_stephen
        }
      end
    end
  end
end
