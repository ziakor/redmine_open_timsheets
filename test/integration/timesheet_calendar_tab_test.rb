# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Covers the hook wiring, not the JavaScript: the point is that the native
# spent-time screens expose the URL the script has to insert.
class TimesheetCalendarTabTest < Redmine::ControllerTest
  tests TimelogController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :enumerations,
           :projects_trackers, :enabled_modules, :time_entries

  def setup
    @request.session[:user_id] = 2
  end

  def test_tab_data_is_exposed_on_the_global_spent_time_list
    get :index

    assert_response :success
    assert_select '#ots-calendar-tab-data[data-url=?]', '/open_timesheets/calendar'
  end

  def test_tab_data_is_exposed_on_a_project_spent_time_list
    get :index, params: { project_id: 1 }

    assert_response :success
    assert_select '#ots-calendar-tab-data[data-url^=?]', '/projects/ecookbook/open_timesheets/calendar'
  end

  def test_tab_data_is_exposed_on_the_report_screen
    get :report, params: { project_id: 1 }

    assert_response :success
    assert_select '#ots-calendar-tab-data', count: 1
  end

  def test_tab_data_carries_the_current_filters
    get :index, params: { set_filter: 1, f: ['user_id'],
                          op: { 'user_id' => '=' }, v: { 'user_id' => ['2'] } }

    assert_response :success
    assert_select '#ots-calendar-tab-data[data-url*=?]', 'user_id'
  end

  def test_tab_data_is_absent_from_unrelated_screens
    get :new

    assert_response :success
    assert_select '#ots-calendar-tab-data', count: 0
  end

  def test_the_stylesheet_is_loaded
    get :index

    assert_select 'head link[href*=?]', 'open_timesheets'
  end

  def test_the_script_is_only_loaded_where_the_tab_is_injected
    get :index
    assert_select 'script[src*=?]', 'open_timesheets', count: 1

    get :new
    assert_select 'script[src*=?]', 'open_timesheets', count: 0
  end
end
