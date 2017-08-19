require "rails"
require "active_support/core_ext"
require "action_controller"
require "swagger/docs"
require "ostruct"
require "json"
require 'pathname'

DEFAULT_VER = Swagger::Docs::Generator::DEFAULT_VER

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.color = true
  config.filter_run_when_matching :focus

  config.before(:each) do
    Swagger::Docs::Config.base_api_controller = nil # use default object
  end
end

def generate(config)
  Swagger::Docs::Generator::write_docs(config)
end

def get_api_paths(apis, path)
  apis.select{|api| api["path"] == path}
end

def get_api_operations(apis, path)
  apis = get_api_paths(apis, path)
  apis.collect{|api| api["operations"]}.flatten
end

def get_api_operation(apis, path, method)
  operations = get_api_operations(apis, path)
  operations.each{|operation| return operation if operation["method"] == method.to_s}
  nil
end

def get_api_parameter(api, name)
  api["parameters"].each{|param| return param if param["name"] == name}
  nil
end
