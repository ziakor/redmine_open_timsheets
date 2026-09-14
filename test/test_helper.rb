# frozen_string_literal: true

begin
  require File.expand_path('../../../test/test_helper', __dir__)
rescue LoadError, StandardError
  require 'minitest/autorun'
  require 'active_support'
  require 'active_support/test_case'
end
