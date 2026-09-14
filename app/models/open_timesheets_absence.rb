# frozen_string_literal: true

class OpenTimesheetsAbsence < ApplicationRecord
  self.table_name = 'open_timesheets_absences'

  DEFAULT_TYPES = %w[conges maladie formation autre].freeze

  belongs_to :user

  validates :user_id, :start_date, :end_date, :absence_type, presence: true
  # The lambda receives the record, so the allowed list is resolved at
  # validation time and follows the plugin setting without a restart.
  validates :absence_type,
            inclusion: { in: ->(record) { record.class.available_types } },
            allow_blank: true

  validate :end_date_after_start_date
  validate :half_day_is_a_single_day
  validate :no_overlap_for_user

  # "Two ranges overlap when each starts before the other ends" is one rule, and
  # it is needed both to find the absences of a month and to reject a duplicate.
  # Defined once here so the two uses cannot drift apart.
  scope :overlapping, lambda { |user_id, from, to|
    where(user_id: user_id)
      .where('start_date <= ? AND end_date >= ?', to, from)
  }

  scope :covering, ->(user, range) { overlapping(user.id, range.first, range.last) }

  def self.available_types
    Setting.plugin_redmine_open_timesheets['absence_types'].presence || DEFAULT_TYPES
  end

  def covers?(date)
    return false if start_date.blank? || end_date.blank?

    (start_date..end_date).cover?(date)
  end

  # A half day still leaves the other half worked, so the day remains one the
  # user has to declare. Only a full day removes it from the expected days.
  def full_day?
    !half_day?
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, :greater_than_start_date)
  end

  # A half day spread over a range has no meaning: half of which day?
  def half_day_is_a_single_day
    return unless half_day?
    return if start_date.blank? || end_date.blank?
    return if start_date == end_date

    errors.add(:half_day, :half_day_needs_single_date)
  end

  def no_overlap_for_user
    return unless overlap_checkable?

    errors.add(:base, :absence_overlaps) if conflicting_absences.exists?
  end

  # Nothing to compare against until the three columns the rule needs are set;
  # their own presence validations report the missing ones.
  def overlap_checkable?
    user_id.present? && start_date.present? && end_date.present?
  end

  # An existing record must not be reported as overlapping itself.
  def conflicting_absences
    scope = self.class.overlapping(user_id, start_date, end_date)
    persisted? ? scope.where.not(id: id) : scope
  end
end
