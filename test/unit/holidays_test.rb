# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class HolidaysTest < ActiveSupport::TestCase
  H = RedmineOpenTimesheets::Holidays

  def setup
    H.reset_cache!
  end

  def test_easter_reference_years
    assert_equal Date.new(2024, 3, 31), H.easter(2024)
    assert_equal Date.new(2025, 4, 20), H.easter(2025)
    assert_equal Date.new(2026, 4, 5),  H.easter(2026)
    assert_equal Date.new(2027, 3, 28), H.easter(2027)
    assert_equal Date.new(2030, 4, 21), H.easter(2030)
  end

  def test_movable_holidays_2026
    days = H.for_year(2026)
    assert_equal :holiday_easter_monday, days[Date.new(2026, 4, 6)]
    assert_equal :holiday_ascension,     days[Date.new(2026, 5, 14)]
    assert_equal :holiday_whit_monday,   days[Date.new(2026, 5, 25)]
  end

  def test_fixed_holidays_2026
    days = H.for_year(2026)
    [[1, 1], [5, 1], [5, 8], [7, 14], [8, 15], [11, 1], [11, 11], [12, 25]].each do |month, day|
      assert days.key?(Date.new(2026, month, day)), "#{day}/#{month}/2026 devrait etre ferie"
    end
  end

  def test_france_has_eleven_holidays
    assert_equal 11, H.for_year(2026).size
    assert_equal 11, H.for_year(2027).size
  end

  def test_alsace_moselle_adds_two_holidays
    days = H.for_year(2026, region: 'fr_alsace_moselle')
    assert_equal 13, days.size
    assert_equal :holiday_good_friday, days[Date.new(2026, 4, 3)]
    assert_equal :holiday_st_stephen,  days[Date.new(2026, 12, 26)]
  end

  def test_unknown_region_falls_back_to_france
    assert_equal H.for_year(2026), H.for_year(2026, region: 'zz_unknown')
  end

  def test_holiday_predicate
    assert     H.holiday?(Date.new(2026, 7, 14))
    assert_not H.holiday?(Date.new(2026, 7, 15))
  end

  def test_results_are_memoized
    assert_same H.for_year(2026), H.for_year(2026)
  end
end
