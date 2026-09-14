# frozen_string_literal: true

class TimesheetTeamController < ApplicationController
  menu_item :time_entries

  before_action :require_login
  before_action :authorize_team_view

  helper :timesheet_calendar

  include RedmineOpenTimesheets::PeriodParams

  def show
    prepare_period

    users = OpenTimesheetsExemption.tracked_users
    @team = RedmineOpenTimesheets::TeamSummary.new(
      users: users, range: @range, entries: entries_for(users)
    )

    respond_to do |format|
      format.html
      format.csv { send_csv }
    end
  end

  private

  def send_csv
    data = Redmine::Export::CSV.generate(encoding: params[:encoding]) do |csv|
      csv << %i[user missing declared expected completion hours].map do |key|
        l(:"field_open_timesheets_team_csv_#{key}")
      end
      @team.rows.each { |row| csv << csv_row(row) }
    end
    send_data(data, type: 'text/csv; header=present',
                    filename: "open_timesheets_team_#{@date.strftime('%Y-%m')}.csv")
  end

  def csv_row(row)
    [row.user.login, row.missing_days, row.declared_days, row.expected_days,
     row.completion_percent, row.hours.round(2)]
  end

  # TimeEntry.visible on purpose: the plugin opens no door Redmine keeps shut.
  # A viewer who cannot see a project will not see the days logged on it, so
  # their counts may overstate what is missing. Administrators, the primary
  # audience here, see everything.
  def entries_for(users)
    TimeEntry.visible
             .where(spent_on: @range, user_id: users.map(&:id))
             .to_a
  end

  def authorize_team_view
    return if OpenTimesheetsTeamViewer.allowed?(User.current)

    deny_access
  end
end
