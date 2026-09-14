# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class OpenTimesheetsAbsenceTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses

  def build_absence(attrs = {})
    OpenTimesheetsAbsence.new({
      user_id: 2,
      start_date: Date.new(2026, 8, 3),
      end_date: Date.new(2026, 8, 14),
      absence_type: 'conges'
    }.merge(attrs))
  end

  def test_valid_absence
    assert build_absence.valid?
  end

  def test_end_date_must_not_precede_start_date
    absence = build_absence(end_date: Date.new(2026, 8, 1))
    assert_not absence.valid?
    assert absence.errors[:end_date].present?
  end

  def test_single_day_absence_is_valid
    assert build_absence(end_date: Date.new(2026, 8, 3)).valid?
  end

  def test_absence_type_must_be_known
    assert_not build_absence(absence_type: 'vacances_sur_mars').valid?
  end

  def test_half_day_requires_a_single_date
    assert_not build_absence(half_day: true).valid?
    assert     build_absence(half_day: true,
                             start_date: Date.new(2026, 8, 3),
                             end_date: Date.new(2026, 8, 3)).valid?
  end

  def test_overlapping_absences_are_rejected
    build_absence.save!
    overlapping = build_absence(start_date: Date.new(2026, 8, 10),
                                end_date: Date.new(2026, 8, 20))
    assert_not overlapping.valid?
    assert overlapping.errors[:base].present?
  end

  def test_adjacent_absences_are_accepted
    build_absence.save!
    adjacent = build_absence(start_date: Date.new(2026, 8, 15),
                             end_date: Date.new(2026, 8, 20))
    assert adjacent.valid?
  end

  def test_an_existing_absence_does_not_overlap_itself
    absence = build_absence
    absence.save!
    absence.comments = 'edited'
    assert absence.valid?
  end

  def test_overlap_is_scoped_to_the_user
    build_absence.save!
    other_user = build_absence(user_id: 3)
    assert other_user.valid?
  end

  def test_covers
    absence = build_absence
    assert     absence.covers?(Date.new(2026, 8, 3))
    assert     absence.covers?(Date.new(2026, 8, 14))
    assert_not absence.covers?(Date.new(2026, 8, 15))
  end

  def test_full_day_by_default
    assert build_absence.full_day?
  end

  def test_a_half_day_is_not_a_full_day
    absence = build_absence(half_day: true,
                            start_date: Date.new(2026, 8, 3),
                            end_date: Date.new(2026, 8, 3))
    assert_not absence.full_day?
  end

  def test_covering_scope
    build_absence.save!
    found = OpenTimesheetsAbsence.covering(User.find(2),
                                           Date.new(2026, 8, 1)..Date.new(2026, 8, 31))
    assert_equal 1, found.size
    none = OpenTimesheetsAbsence.covering(User.find(2),
                                          Date.new(2026, 9, 1)..Date.new(2026, 9, 30))
    assert_empty none
  end
end
