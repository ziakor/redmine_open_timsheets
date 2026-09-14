# frozen_string_literal: true

# A user exempt from day tracking. Everyone is tracked by default; a row here
# is the exception, so nothing has to be created when a colleague joins.
class OpenTimesheetsExemption < ApplicationRecord
  self.table_name = 'open_timesheets_exemptions'

  belongs_to :user

  validates :user_id, presence: true, uniqueness: true

  def self.exempt?(user_id)
    exists?(user_id: user_id)
  end

  def self.exempt_user_ids
    pluck(:user_id)
  end

  # Everyone active except those explicitly exempt. Ordered so the team view is
  # stable between reloads.
  def self.tracked_users
    User.active.where.not(id: exempt_user_ids).sorted.to_a
  end

  # Idempotent: the caller states the wanted outcome, not the transition.
  def self.set(user_id, exempt:)
    if exempt
      find_or_create_by!(user_id: user_id)
    else
      where(user_id: user_id).delete_all
      nil
    end
  end
end
