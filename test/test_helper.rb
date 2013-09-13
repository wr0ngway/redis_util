require 'rubygems'

if ENV['CI']
  require 'coveralls'
  Coveralls.wear!
end

require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'minitest/autorun'
require 'minitest/should'
require "minitest/reporters"
require 'mocha/setup'

reporter = ENV['REPORTER']
reporter = case reporter
  when 'none' then nil
  when 'spec' then MiniTest::Reporters::SpecReporter.new
  when 'progress' then MiniTest::Reporters::ProgressReporter.new
  else MiniTest::Reporters::DefaultReporter.new
end
MiniTest::Reporters.use!(reporter) if reporter

require 'redis_util'
GemLogger.default_logger = Logger.new("/dev/null")

class MiniTest::Should::TestCase

  require 'redis_util/test_helper'
  include RedisUtil::TestHelper

end

# Allow triggering single tests when running from rubymine
# reopen the installed runner so we don't step on runner customizations
class << MiniTest::Unit.runner
  # Rubymine sends --name=/\Atest\: <context> should <should>\./
  # Minitest runs each context as a suite
  # Minitest filters methods by matching against: <suite>#test_0001_<should>
  # Nested contexts are separted by spaces in rubymine, but ::s in minitest
  
  def _run_suites(suites, type)
    if options[:filter]
      if options[:filter] =~ /\/\\Atest\\: (.*) should (.*)\\\.\//
        context_filter = $1
        should_filter = $2
        should_filter.strip!
        should_filter.gsub!(" ", "_")
        should_filter.gsub!(/\W/, "")
        context_filter = context_filter.gsub(" ", "((::)| )")
        options[:filter] = "/\\A#{context_filter}(Test)?#test(_\\d+)?_should_#{should_filter}\\Z/"
      end
    end
    
    super
  end
  
  # Prevent "Empty test suite" verbosity when running in rubymine
  def _run_suite(suite, type)
    
    filter = options[:filter] || '/./'
    filter = Regexp.new $1 if filter =~ /\/(.*)\//    
    all_test_methods = suite.send "#{type}_methods"
    filtered_test_methods = all_test_methods.find_all { |m|
      filter === m || filter === "#{suite}##{m}"
    }
    
    if filtered_test_methods.size > 0    
      super
    else
      [0, 0]
    end
  end
end
