# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class OpenTimesheetsTeamViewerTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses

  def test_administrators_are_allowed_without_a_row
    assert OpenTimesheetsTeamViewer.allowed?(User.find(1))
    assert_equal 0, OpenTimesheetsTeamViewer.count
  end

  def test_an_ordinary_user_is_denied_by_default
    assert_not OpenTimesheetsTeamViewer.allowed?(User.find(2))
  end

  def test_a_row_allows_an_ordinary_user
    OpenTimesheetsTeamViewer.create!(user_id: 2)
    assert OpenTimesheetsTeamViewer.allowed?(User.find(2))
    assert_not OpenTimesheetsTeamViewer.allowed?(User.find(3))
  end

  def test_anonymous_is_denied
    assert_not OpenTimesheetsTeamViewer.allowed?(User.anonymous)
    assert_not OpenTimesheetsTeamViewer.allowed?(nil)
  end

  def test_user_id_must_be_unique
    OpenTimesheetsTeamViewer.create!(user_id: 2)
    assert_not OpenTimesheetsTeamViewer.new(user_id: 2).valid?
  end

  def test_set_is_idempotent
    OpenTimesheetsTeamViewer.set(2, allowed: true)
    OpenTimesheetsTeamViewer.set(2, allowed: true)
    assert_equal 1, OpenTimesheetsTeamViewer.where(user_id: 2).count

    OpenTimesheetsTeamViewer.set(2, allowed: false)
    OpenTimesheetsTeamViewer.set(2, allowed: false)
    assert_equal 0, OpenTimesheetsTeamViewer.where(user_id: 2).count
  end
end
