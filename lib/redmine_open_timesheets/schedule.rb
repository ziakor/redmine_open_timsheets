# frozen_string_literal: true

module RedmineOpenTimesheets
  # Tells whether a given day is one the user has to declare.
  #
  # There is no notion of expected hours: everyone is on a day-based contract
  # (forfait jours), so a day is either owed or not. Hours logged in Redmine
  # stay informative and are never compared to a target.
  #
  # Absences of the range are loaded in a single query at construction time;
  # no per-day query is issued.
  class Schedule
    def initialize(user, range)
      @user = user
      @exempt = OpenTimesheetsExemption.exempt?(user.id)
      @absences = OpenTimesheetsAbsence.covering(user, range).to_a
    end

    # Evaluation order: the first matching criterion wins.
    def expected?(date)
      return false if exempt?
      return false if non_working_week_day?(date)
      return false if holiday_name(date)

      absence = absence_on(date)
      # A half day leaves the other half worked, so the day is still owed.
      absence.nil? || !absence.full_day?
    end

    def exempt?
      @exempt
    end

    def absence_on(date)
      @absences.find { |absence| absence.covers?(date) }
    end

    def holiday_name(date)
      Holidays.for_year(date.year, region: holiday_region)[date]
    end

    private

    def non_working_week_day?(date)
      Setting.non_working_week_days.include?(date.cwday.to_s)
    end

    def holiday_region
      Setting.plugin_redmine_open_timesheets['holiday_region'].presence ||
        Holidays::DEFAULT_REGION
    end
  end
end
