#!/usr/bin/ruby -w
#
#	Tests for the PluginFactory module
#

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname
	
	$:.unshift( basedir + "lib" )
	$:.unshift( basedir + "tests" )
}

require "pluginfactory"
require "test/unit"
require 'mybase'

class FactoryTests < Test::Unit::TestCase
	
	def setup
		if $DEBUG
			PluginFactory.logger_callback = lambda {|lvl, msg|
				$deferr.puts msg
			}
		end
	end

	def test_inclusion_of_mixin_should_add_a_create_class_method
		subclass = rval = nil

		assert_nothing_raised do
			subclass = Class::new { include PluginFactory }
		end

		assert_respond_to subclass, :create
	end


	@@subs = %w{subof OtherSub SubOfMyBase othersubmybase deepsubof}


	def test_create_should_fetch_search_dirs_from_base_class
		subclass = rval = nil

		assert_nothing_raised do
			subclass = Class::new {
				include PluginFactory
				@method_called = false

				class << self
					attr_accessor :method_called
				end
				def self.derivative_dirs
					method_called = true
				end
			}
		end

		
	end

	def test_creation 
		@@subs.each do |sub|
			result = nil
			assert_nothing_raised		{result = MyBase.create(sub)}
			assert						result.kind_of?(MyBase)
			assert_match				%r[#{sub}]i, result.class.name
		end
	end


end # class FactoryTests
