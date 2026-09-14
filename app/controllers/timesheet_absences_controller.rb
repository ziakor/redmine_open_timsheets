# frozen_string_literal: true

class TimesheetAbsencesController < ApplicationController
  before_action :require_login
  before_action :find_target_user
  before_action :find_absence, only: %i[edit update destroy]

  def index
    @absences = OpenTimesheetsAbsence.where(user_id: @user.id).order(start_date: :desc)
  end

  def new
    @absence = OpenTimesheetsAbsence.new(user_id: @user.id, start_date: User.current.today)
  end

  def create
    @absence = OpenTimesheetsAbsence.new(absence_params)
    # The owner is never read from the form: it is resolved and authorised in
    # find_target_user.
    @absence.user_id = @user.id

    if @absence.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to timesheet_absences_path(user_id: submitted_user_id)
    else
      render :new
    end
  end

  def edit; end

  def update
    @absence.attributes = absence_params

    if @absence.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to timesheet_absences_path(user_id: submitted_user_id)
    else
      render :edit
    end
  end

  def destroy
    @absence.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to timesheet_absences_path(user_id: submitted_user_id)
  end

  private

  # An ordinary user manages their own absences only. An administrator may act
  # for someone else through an explicit parameter. Anything else is denied
  # rather than silently rewritten to the current user: quietly ignoring an
  # unauthorised request would hide the inconsistency.
  def find_target_user
    if params[:user_id].blank?
      @user = User.current
      return
    end

    @user = User.find(params[:user_id])
    deny_access unless @user == User.current || User.current.admin?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_absence
    @absence = OpenTimesheetsAbsence.find(params[:id])
    deny_access unless @absence.user_id == @user.id
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def submitted_user_id
    params[:user_id].presence
  end

  # user_id is deliberately absent from the permitted list, so an owner cannot
  # be set from the form even if the assignment above were removed one day.
  def absence_params
    params.require(:open_timesheets_absence)
          .permit(:start_date, :end_date, :absence_type, :half_day, :comments)
  end
end
