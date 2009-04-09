#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'

require 'rubygems'
require 'minitest/unit'

require 'fixture_optparse'


class OptionParser
  class Switch
      attr_writer :block
  end
end

class MyOptparse < OpenStruct
  def initialize(args)
    super()
    opts=OptionParser.new { |opts|
      Fixture_Optparse::OPTIONS.each { |option_args|
        opts.on(*option_args)
      }

      # Missing blocks default to setting the value
      opts.top.list.each { |opt|
        opt.block = proc { |value|
          # '--blah' -> 'blah'
          name = opt.long[0][2..-1]
          # '--[no-]verbose' -> 'verbose'
          name = name[5..-1] if name[0..4] == '[no-]'
          self.__send__ "#{name}=", value
        } if opt.block.nil?
      }
    }

    opts.on_tail("-h", "--help", "Show this message") do                                 
      puts opts                                                                          
    end   

    opts.parse(args)
  end
end

class Test_MyOptParse < MiniTest::Unit::TestCase
  include Fixture_Optparse
  Fixture_Optparse::SKIP_FAILING_TESTS = false
  def setup
    @parser = MyOptparse
  end

  def test_version
    [
      '-h',
      '--help',
    ].each do |x|
      parser_assert_equal_out(
"Usage: test_optparse [options]
    -i, --inplace                    Edit ARGV files in place
                                       (make backup)
        --delay N                    Delay N seconds before executing
    -t, --time [TIME]                Begin execution at given time
    -F, --irs [OCTAL]                Specify record separator (default \\0)
        --list x,y,z                 Example 'list' of arguments
        --code CODE                  Select encoding
                                       (sjis,jis,iso-2022-jp,shift_jis,euc-jp,utf8,binary)
        --type [TYPE]                Select transfer type (text, binary, auto)
    -v, --[no-]verbose               Run verbosely
    -w, --werbose                    Run werbosely
    -h, --help                       Show this message
"     ,x)
    end
  end
end

MiniTest::Unit.autorun
