# frozen_string_literal: true

require_relative 'lib/redmine_open_timesheets/period_params'
require_relative 'lib/redmine_open_timesheets/holidays'
require_relative 'lib/redmine_open_timesheets/schedule'
require_relative 'lib/redmine_open_timesheets/month_summary'
require_relative 'lib/redmine_open_timesheets/team_summary'
require_relative 'lib/redmine_open_timesheets/calendar_payload'
require_relative 'lib/redmine_open_timesheets/reminder'
require_relative 'lib/redmine_open_timesheets/hooks'

Redmine::Plugin.register :redmine_open_timesheets do
  name 'Redmine Open Timesheets'
  author 'Dimitri Hauet'
  description 'Vue calendrier de suivi des journees declarees, avec absences et jours feries.'
  version '0.1.0'
  url 'https://github.com/ziakor/redmine_open_timesheets'
  requires_redmine version_or_higher: '6.0.0'

  settings default: {
    'holiday_region' => 'fr',
    'reminder_lookback_days' => '7',
    'absence_types' => %w[conges maladie formation autre]
  }, partial: 'settings/open_timesheets_settings'

  menu :admin_menu, :open_timesheets_tracking,
       { controller: 'timesheet_tracking', action: 'index' },
       caption: :label_open_timesheets_tracking,
       html: { class: 'icon icon-time' }
end
