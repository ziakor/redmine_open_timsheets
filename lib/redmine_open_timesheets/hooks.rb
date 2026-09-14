# frozen_string_literal: true

module RedmineOpenTimesheets
  class Hooks < Redmine::Hook::ViewListener
    # Loaded on every page: the rules are scoped under ots-* classes and cost
    # nothing elsewhere.
    def view_layouts_base_html_head(_context = {})
      stylesheet_link_tag('open_timesheets', plugin: 'redmine_open_timesheets')
    end

    # The Details/Report tab strip lives in timelog/_date_range.html.erb, which
    # exposes no hook. The link is injected from the client rather than by
    # overriding that partial: if Redmine changes it, the tab disappears
    # instead of the spent-time screen breaking.
    render_on :view_layouts_base_body_bottom, partial: 'timesheet_calendar/tab_injection'

    render_on :view_account_right_bottom, partial: 'timesheet_calendar/user_profile_link'
  end
end
