# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class TimesheetAbsencesControllerTest < Redmine::ControllerTest
  fixtures :users, :email_addresses, :roles

  def setup
    Setting.plugin_redmine_open_timesheets = {
      'holiday_region' => 'fr',
      'absence_types' => %w[conges maladie formation autre]
    }
    @request.session[:user_id] = 2
  end

  def valid_attributes(overrides = {})
    { 'start_date' => '2026-08-03', 'end_date' => '2026-08-14',
      'absence_type' => 'conges' }.merge(overrides)
  end

  def create_absence(user_id, overrides = {})
    OpenTimesheetsAbsence.create!({
      user_id: user_id, absence_type: 'conges',
      start_date: Date.new(2026, 8, 3), end_date: Date.new(2026, 8, 14)
    }.merge(overrides))
  end

  def test_index_lists_only_my_absences
    create_absence(2)
    create_absence(3)

    get :index

    assert_response :success
    assert_select 'table.list tbody tr', count: 1
  end

  def test_requires_login
    @request.session[:user_id] = nil

    get :index

    assert_response :found
  end

  def test_create_my_own_absence
    assert_difference 'OpenTimesheetsAbsence.count', 1 do
      post :create, params: { open_timesheets_absence: valid_attributes }
    end

    assert_redirected_to timesheet_absences_path
    assert_equal 2, OpenTimesheetsAbsence.last.user_id
  end

  def test_a_submitted_user_id_is_ignored
    post :create, params: { open_timesheets_absence: valid_attributes('user_id' => '3') }

    assert_equal 2, OpenTimesheetsAbsence.last.user_id
  end

  def test_cannot_manage_another_user_absences
    post :create, params: { user_id: 3, open_timesheets_absence: valid_attributes }

    assert_response :forbidden
    assert_equal 0, OpenTimesheetsAbsence.where(user_id: 3).count
  end

  def test_admin_can_manage_another_user_absences
    @request.session[:user_id] = 1

    assert_difference 'OpenTimesheetsAbsence.where(user_id: 3).count', 1 do
      post :create, params: { user_id: 3, open_timesheets_absence: valid_attributes }
    end
  end

  def test_an_unknown_target_user_is_a_404
    @request.session[:user_id] = 1

    get :index, params: { user_id: 999_999 }

    assert_response :not_found
  end

  def test_an_overlapping_absence_is_rejected_with_a_message
    create_absence(2)

    assert_no_difference 'OpenTimesheetsAbsence.count' do
      post :create, params: { open_timesheets_absence: valid_attributes('start_date' => '2026-08-10',
                                                                        'end_date' => '2026-08-20') }
    end

    assert_response :success
    assert_select '#errorExplanation'
  end

  def test_a_half_day_over_a_range_is_rejected
    assert_no_difference 'OpenTimesheetsAbsence.count' do
      post :create, params: { open_timesheets_absence: valid_attributes('half_day' => '1') }
    end

    assert_select '#errorExplanation'
  end

  def test_a_half_day_on_a_single_date_is_accepted
    assert_difference 'OpenTimesheetsAbsence.count', 1 do
      post :create, params: { open_timesheets_absence: valid_attributes('end_date' => '2026-08-03',
                                                                        'half_day' => '1') }
    end

    assert OpenTimesheetsAbsence.last.half_day?
  end

  def test_cannot_edit_someone_else_absence
    other = create_absence(3)

    get :edit, params: { id: other.id }

    assert_response :forbidden
  end

  def test_update_my_own_absence
    mine = create_absence(2)

    put :update, params: { id: mine.id,
                           open_timesheets_absence: valid_attributes('absence_type' => 'maladie') }

    assert_redirected_to timesheet_absences_path
    assert_equal 'maladie', mine.reload.absence_type
  end

  def test_destroy_my_own_absence
    mine = create_absence(2)

    assert_difference 'OpenTimesheetsAbsence.count', -1 do
      delete :destroy, params: { id: mine.id }
    end

    assert_redirected_to timesheet_absences_path
  end

  def test_cannot_destroy_someone_else_absence
    other = create_absence(3)

    assert_no_difference 'OpenTimesheetsAbsence.count' do
      delete :destroy, params: { id: other.id }
    end

    assert_response :forbidden
  end
end
