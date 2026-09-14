# frozen_string_literal: true

class TimesheetCalendarController < ApplicationController
  menu_item :time_entries

  before_action :find_calendar_project
  before_action :authorize_calendar

  helper :queries
  include QueriesHelper
  helper :timelog
  helper :issues
  helper :routes
  helper :timesheet_calendar

  include RedmineOpenTimesheets::PeriodParams

  accept_api_auth :show

  rescue_from Query::StatementInvalid, with: :query_statement_invalid
  rescue_from Query::QueryError, with: :query_error

  def show
    prepare_period

    retrieve_time_entry_query
    default_to_current_user
    @summary = build_summary if @query.valid?

    respond_to do |format|
      format.html
      format.api  { render_payload_or_error { |payload| render json: payload.to_hash } }
      format.csv  { render_payload_or_error { |payload| send_csv(payload) } }
    end
  end

  private

  # Private in TimelogController, so redefined here. Depends only on
  # QueriesHelper#retrieve_query and TimeEntryQuery#results_scope.
  # The false argument reproduces Redmine's choice not to keep the spent-time
  # query in session.
  def retrieve_time_entry_query
    retrieve_query(TimeEntryQuery, false)
  end

  def time_entry_scope(options = {})
    @query.results_scope(options)
  end

  # Personal mode is the default entry point. Without this the project tab
  # would open in collective mode and report no missing day at all.
  def default_to_current_user
    return if @query.has_filter?('user_id')

    @query.add_filter('user_id', '=', ['me'])
  end

  def build_summary
    grid_range = @calendar.startdt..@calendar.enddt

    RedmineOpenTimesheets::MonthSummary.new(
      entries: entries_in(grid_range),
      range: grid_range,
      counted_range: @range,
      users: scoped_users
    )
  end

  def render_payload_or_error
    return render_error(message: @query.errors.full_messages.join(', '), status: 422) unless @query.valid?

    yield payload
  end

  def payload
    RedmineOpenTimesheets::CalendarPayload.new(
      summary: @summary,
      range: @range,
      period: @period
    )
  end

  def send_csv(payload)
    data = Redmine::Export::CSV.generate(encoding: params[:encoding]) do |csv|
      csv << payload.csv_headers
      payload.csv_rows.each { |row| csv << row }
    end
    send_data(data, type: 'text/csv; header=present',
                    filename: "open_timesheets_#{@date.strftime('%Y-%m')}.csv")
  end

  def entries_in(range)
    time_entry_scope
      .where(spent_on: range)
      .preload(:project, :user, issue: %i[project tracker status])
      .to_a
  end

  # Read from the filter, never from the returned entries: an empty month has
  # no users and would be misclassified as collective, hiding the very gaps the
  # calendar exists to reveal.
  def scoped_users
    return [] unless @query.operator_for('user_id') == '='

    ids = Array(@query.values_for('user_id')).map do |value|
      value == 'me' ? User.current.id : value.to_i
    end
    User.where(id: ids).to_a
  end

  # ApplicationController#find_optional_project cannot be used here: besides
  # loading the project it also checks allowed_to?(controller:, action:), which
  # requires the action to be mapped to a permission. This plugin deliberately
  # declares none, so that check would always deny. The permission is verified
  # explicitly just below instead.
  def find_calendar_project
    return if params[:project_id].blank?

    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_calendar
    return if User.current.allowed_to?(:view_time_entries, @project, global: @project.nil?)

    deny_access
  end
end
