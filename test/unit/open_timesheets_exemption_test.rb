# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class OpenTimesheetsExemptionTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses

  def test_everyone_is_tracked_by_default
    assert_not OpenTimesheetsExemption.exempt?(2)
  end

  def test_a_row_marks_the_user_exempt
    OpenTimesheetsExemption.create!(user_id: 2)
    assert OpenTimesheetsExemption.exempt?(2)
    assert_not OpenTimesheetsExemption.exempt?(3)
  end

  def test_user_id_must_be_unique
    OpenTimesheetsExemption.create!(user_id: 2)
    assert_not OpenTimesheetsExemption.new(user_id: 2).valid?
  end

  def test_set_exempt_creates_a_row
    OpenTimesheetsExemption.set(2, exempt: true)
    assert OpenTimesheetsExemption.exempt?(2)
  end

  def test_set_exempt_is_idempotent
    OpenTimesheetsExemption.set(2, exempt: true)
    OpenTimesheetsExemption.set(2, exempt: true)
    assert_equal 1, OpenTimesheetsExemption.where(user_id: 2).count
  end

  def test_set_tracked_removes_the_row
    OpenTimesheetsExemption.create!(user_id: 2)
    OpenTimesheetsExemption.set(2, exempt: false)
    assert_not OpenTimesheetsExemption.exempt?(2)
  end

  def test_set_tracked_on_an_already_tracked_user_is_a_no_op
    OpenTimesheetsExemption.set(2, exempt: false)
    assert_equal 0, OpenTimesheetsExemption.count
  end

  def test_exempt_user_ids
    OpenTimesheetsExemption.create!(user_id: 2)
    OpenTimesheetsExemption.create!(user_id: 3)
    assert_equal [2, 3], OpenTimesheetsExemption.exempt_user_ids.sort
  end
end
