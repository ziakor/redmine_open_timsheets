# frozen_string_literal: true

# Plugin routes are appended after the core ones, so they have lower priority.
# "/time_entries/calendar" was therefore swallowed by the core route
# GET /time_entries/:id (timelog#show with id "calendar"), verified with
# Rails.application.routes.recognize_path. Both calendar routes live under the
# plugin namespace instead: no collision now, and none if the core routes move.
RedmineApp::Application.routes.draw do
  get 'open_timesheets/calendar',
      to: 'timesheet_calendar#show',
      as: 'timesheet_calendar'

  get 'projects/:project_id/open_timesheets/calendar',
      to: 'timesheet_calendar#show',
      as: 'project_timesheet_calendar'

  get  'open_timesheets/tracking', to: 'timesheet_tracking#index', as: 'open_timesheets_tracking'
  post 'open_timesheets/tracking', to: 'timesheet_tracking#update'

  get 'open_timesheets/team', to: 'timesheet_team#show', as: 'open_timesheets_team'

  resources :timesheet_absences, except: [:show]
end
