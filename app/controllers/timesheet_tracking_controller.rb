# frozen_string_literal: true

class TimesheetTrackingController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :require_admin

  def index
    load_users
  end

  def update
    # Iterating over the users rather than over the submitted hash: the server
    # decides who exists, the form only supplies values. An unknown id in the
    # payload can therefore never create a row.
    User.active.each { |user| apply_settings_for(user) }

    flash[:notice] = l(:notice_successful_update)
    redirect_to open_timesheets_tracking_path
  end

  private

  def apply_settings_for(user)
    OpenTimesheetsExemption.set(user.id, exempt: !checked?(:tracking, user))

    # Administrators may open the team view without a row, so storing one for
    # them would be dead data.
    return if user.admin?

    OpenTimesheetsTeamViewer.set(user.id, allowed: checked?(:team_view, user))
  end

  def checked?(group, user)
    params.dig(group, user.id.to_s).to_s == '1'
  end

  def load_users
    @users = User.active.sorted.to_a
    @exempt_user_ids = OpenTimesheetsExemption.exempt_user_ids.to_set
    @team_viewer_ids = OpenTimesheetsTeamViewer.allowed_user_ids.to_set
  end
end
