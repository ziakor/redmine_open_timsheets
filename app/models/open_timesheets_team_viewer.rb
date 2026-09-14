# frozen_string_literal: true

# A user explicitly allowed to open the team view. Administrators do not need a
# row; everybody else does.
#
# The restriction is deliberate but not a data barrier: anyone holding
# :view_time_entries already sees other people's entries in Redmine. What this
# list gates is the aggregated "who is late" reading, which is a management
# artefact rather than new data.
class OpenTimesheetsTeamViewer < ApplicationRecord
  self.table_name = 'open_timesheets_team_viewers'

  belongs_to :user

  validates :user_id, presence: true, uniqueness: true

  def self.allowed?(user)
    return false if user.nil? || !user.logged?
    return true if user.admin?

    exists?(user_id: user.id)
  end

  def self.allowed_user_ids
    pluck(:user_id)
  end

  # Idempotent: the caller states the wanted outcome, not the transition.
  def self.set(user_id, allowed:)
    if allowed
      find_or_create_by!(user_id: user_id)
    else
      where(user_id: user_id).delete_all
      nil
    end
  end
end
