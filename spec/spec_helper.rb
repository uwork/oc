#-*- encoding: utf-8 -*-

ENV['OC_HOME'] = File.dirname(File.dirname(__FILE__))
ENV['CURRENT_DIR'] = ENV['OC_HOME']

require 'logger'
require 'yaml'
require 'hashie'
require 'thor'

Dir[File.join(File.dirname(__FILE__), "../lib/*.rb"),
    File.join(File.dirname(__FILE__), "../commands/*.rb"),
    File.join(File.dirname(__FILE__), "fixtures/*.rb")].each do |file|
  require file
end

$fixtures = {}
Dir[File.join(File.dirname(__FILE__), "fixtures/*.yml")].each do |file|
  data = YAML.load_file(file)
  name = File.basename(file).gsub(/\.yml/, "")
  $fixtures[name] = data
end

$log = Logger.new(STDOUT)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

end
