# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class PluginRegistrationTest < ActiveSupport::TestCase
  def setup
    @plugin = Redmine::Plugin.find(:redmine_open_timesheets)
  end

  def test_plugin_is_registered
    assert_equal 'Redmine Open Timesheets', @plugin.name
  end

  def test_default_settings
    defaults = @plugin.settings[:default]
    assert_equal 'fr', defaults['holiday_region']
    assert_equal %w[conges maladie formation autre], defaults['absence_types']
  end
end
