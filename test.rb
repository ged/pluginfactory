#!/usr/bin/env ruby -w
#
#	Tests for the PluginFactory module
#

$:.unshift(File.join(File.dirname(__FILE__)), "lib")
$:.unshift(File.join(File.dirname(__FILE__)), "tests")

require "pluginfactory"
require "test/unit"

class FactoryTests < Test::Unit::TestCase
	
	def setup
		if $DEBUG
			PluginFactory.logger_callback = lambda {|lvl, msg|
				$deferr.puts msg
			}
		end
	end

	def test_01_inclusion 
		assert_nothing_raised		{require "mybase"}
		assert						MyBase
		assert						MyBase.ancestors.include?( PluginFactory )
	end

	@@subs = %w{subof OtherSub SubOfMyBase othersubmybase deepsubof}

	def test_11_creation 
		@@subs.each {|sub|
			result = nil
			assert_nothing_raised		{result = MyBase.create(sub)}
			assert						result.kind_of?(MyBase)
			assert_match				%r[#{sub}]i, result.class.name
		}
	end


end # class FactoryTests
