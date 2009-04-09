#!/usr/bin/env ruby

require 'rubygems'
require 'commander/blank'
require 'commander/user_interaction'
require 'commander/core_ext'
require 'commander/runner'
require 'commander/command'
require 'commander/help_formatters'

require 'minitest/unit'

require 'fixture_optparse'


class MyCommander < Commander::Runner
  attr_reader :global_options

  def initialize(args)
    super(args)

    program :version, '0.0.1'
    program :description, self.class.name

    Fixture_Optparse::OPTIONS.each { |option_args|
      global_option(*option_args)
    }

    command :foo do |c|
      c.when_called { |args, options| @global_options = options}
    end

    run!
  end

  def marshal_dump
    @global_options.__hash__
  end
end


class Test_Parsers < MiniTest::Unit::TestCase
  include Fixture_Optparse
  Fixture_Optparse::SKIP_FAILING_TESTS = true
  def setup
    @parser = MyCommander
  end

  def test_version
    [
      '--help',
    ].each do |x|
      parser_assert_equal_out(
'Usage: test_commander_optparse [options]
        --blah                       Blah
    -y, --year [YEAR]                Begin execution at given year
    -t, --date [DATE]                Begin execution at given date
    -w, --delay [DELAY]              Delay N seconds before executing
    -h, --help                       Show this message
'     ,x)
    end if not SKIP_FAILING_TESTS
  end
end


MiniTest::Unit.autorun
