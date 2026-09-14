# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class UserProfileCalendarLinkTest < Redmine::ControllerTest
  tests UsersController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :enumerations,
           :projects_trackers, :enabled_modules, :time_entries

  def test_an_administrator_can_open_the_profile_users_calendar
    User.find(1).update!(language: 'fr')
    @request.session[:user_id] = 1

    get :show, params: { id: 6 }

    assert_response :success
    assert_select '#open-timesheets-user-calendar h3', text: 'Suivi du temps'
    assert_select '#open-timesheets-user-calendar a', text: 'Voir le calendrier', count: 1 do |links|
      uri = URI.parse(links.first['href'])
      query = Rack::Utils.parse_nested_query(uri.query)

      assert_equal '/open_timesheets/calendar', uri.path
      assert_equal '1', query['set_filter']
      assert_equal ['user_id'], query['f']
      assert_equal({ 'user_id' => '=' }, query['op'])
      assert_equal({ 'user_id' => ['6'] }, query['v'])
    end
  end

  def test_an_ordinary_user_does_not_see_the_calendar_block
    @request.session[:user_id] = 2

    get :show, params: { id: 2 }

    assert_response :success
    assert_select '#open-timesheets-user-calendar', count: 0
  end

  def test_an_authorized_manager_sees_the_calendar_block
    OpenTimesheetsTeamViewer.create!(user_id: 2)
    @request.session[:user_id] = 2

    get :show, params: { id: 2 }

    assert_response :success
    assert_select '#open-timesheets-user-calendar', count: 1
  end
end
