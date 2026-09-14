# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class TimesheetTrackingControllerTest < Redmine::ControllerTest
  fixtures :users, :email_addresses, :roles

  def test_index_requires_admin
    @request.session[:user_id] = 2

    get :index

    assert_response :forbidden
  end

  def test_index_lists_active_users
    @request.session[:user_id] = 1

    get :index

    assert_response :success
    assert_select 'table.list tbody tr', count: User.active.count
  end

  def test_everyone_is_checked_by_default
    @request.session[:user_id] = 1

    get :index

    # Scoped to the tracking column: the team column also carries a checked box
    # for administrators, and counting both would prove nothing.
    assert_select 'table.list tbody tr input[type=checkbox][name^=?][checked=checked]',
                  'tracking[', count: User.active.count
  end

  def test_unchecking_a_user_exempts_them
    @request.session[:user_id] = 1

    post :update, params: { tracking: { '2' => '0' } }

    assert_redirected_to '/open_timesheets/tracking'
    assert OpenTimesheetsExemption.exempt?(2)
  end

  def test_a_missing_checkbox_means_exempt
    @request.session[:user_id] = 1

    post :update, params: { tracking: {} }

    assert_equal User.active.count, OpenTimesheetsExemption.count
  end

  def test_rechecking_a_user_removes_the_exemption
    OpenTimesheetsExemption.create!(user_id: 2)
    @request.session[:user_id] = 1

    post :update, params: { tracking: { '2' => '1' } }

    assert_not OpenTimesheetsExemption.exempt?(2)
  end

  def test_unknown_user_ids_in_the_form_are_ignored
    # The server decides which users exist; the form only supplies values.
    @request.session[:user_id] = 1

    post :update, params: { tracking: { '999999' => '0' } }

    assert_equal 0, OpenTimesheetsExemption.where(user_id: 999_999).count
  end

  def test_update_requires_admin
    @request.session[:user_id] = 2

    post :update, params: { tracking: { '2' => '0' } }

    assert_response :forbidden
    assert_equal 0, OpenTimesheetsExemption.count
  end

  def test_the_team_access_column_is_listed
    @request.session[:user_id] = 1

    get :index

    assert_select 'table.list thead th', count: 3
  end

  def test_an_administrator_is_labelled_in_french
    User.find(1).update!(language: 'fr')
    @request.session[:user_id] = 1

    get :index

    assert_select 'table.list tbody tr span.ots-note', text: 'Administrateur', count: 1
  end

  def test_granting_team_access
    @request.session[:user_id] = 1

    post :update, params: { tracking: { '2' => '1' }, team_view: { '2' => '1' } }

    assert OpenTimesheetsTeamViewer.allowed?(User.find(2))
  end

  def test_revoking_team_access
    OpenTimesheetsTeamViewer.create!(user_id: 2)
    @request.session[:user_id] = 1

    post :update, params: { tracking: { '2' => '1' } }

    assert_not OpenTimesheetsTeamViewer.exists?(user_id: 2)
  end

  def test_no_row_is_stored_for_an_administrator
    @request.session[:user_id] = 1

    post :update, params: { tracking: {}, team_view: { '1' => '1' } }

    assert_equal 0, OpenTimesheetsTeamViewer.where(user_id: 1).count
    assert OpenTimesheetsTeamViewer.allowed?(User.find(1))
  end

  def test_an_administrator_is_never_exempted_from_the_team_view_by_a_missing_checkbox
    @request.session[:user_id] = 1

    post :update, params: { tracking: {}, team_view: {} }

    assert OpenTimesheetsTeamViewer.allowed?(User.find(1))
  end
end
