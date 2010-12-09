#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'
require 'logger'
require 'pluginfactory'

require 'spec/lib/helpers'

class Plugin
	extend PluginFactory
	def self::derivative_dirs 
		[ 'plugins', 'plugins/private' ]
	end
end

class SubPlugin < Plugin; end
class TestingPlugin < Plugin; end
class BlackSheep < Plugin; end
module Test
	class LoadablePlugin < Plugin; end
end


describe PluginFactory do

	before( :each ) do
		setup_logging( :fatal )
	end

	after( :each ) do
		reset_logging()
	end


	it "calls its logging callback with the level and joined message if set" do
		level = nil; msg = nil
		PluginFactory.logger_callback = lambda {|l, m| level = l; msg = m }
		PluginFactory.logger.level = Logger::DEBUG

		PluginFactory.log.debug( 'message' )
		level.should == :debug
		msg.should == 'message'
	end

	it "doesn't error when its log method is called if no logging callback is set" do
		PluginFactory.logger_callback = nil
		lambda { PluginFactory.log.debug("msg") }.should_not raise_error()
	end


	context "-extended class" do

		it "knows about all of its derivatives" do
			Plugin.derivatives.keys.should include( 'sub' )
			Plugin.derivatives.keys.should include( 'subplugin' )
			Plugin.derivatives.keys.should include( 'SubPlugin' )
			Plugin.derivatives.keys.should include( SubPlugin )
		end

		it "returns derivatives directly if they're already loaded" do
			class AlreadyLoadedPlugin < Plugin; end
			Kernel.should_not_receive( :require )
			Plugin.create( 'alreadyloaded' ).should be_an_instance_of( AlreadyLoadedPlugin )
			Plugin.create( 'AlreadyLoaded' ).should be_an_instance_of( AlreadyLoadedPlugin )
			Plugin.create( 'AlreadyLoadedPlugin' ).should be_an_instance_of( AlreadyLoadedPlugin )
			Plugin.create( AlreadyLoadedPlugin ).should be_an_instance_of( AlreadyLoadedPlugin )
		end

		it "filters errors that happen when creating an instance of derivatives so they " +
			"point to the right place" do
			class PugilistPlugin < Plugin
				def initialize
					raise "Oh noes -- an error!"
				end
			end

			begin
				Plugin.create('pugilist')
			rescue ::Exception => err
				err.backtrace.first.should =~ /#{__FILE__}/
			else
				fail "Expected an exception to be raised"
			end
		end

		it "will refuse to create an object other than one of its derivatives" do
			class Doppelgaenger; end
			lambda { Plugin.create(Doppelgaenger) }.
				should raise_error( ArgumentError, /is not a descendent of/ )
		end


		it "will load new plugins from the require path if they're not loaded yet" do
			loaded_class = nil

			Plugin.should_receive( :require ).with( 'plugins/dazzle_plugin' ).and_return do |*args|
				loaded_class = Class.new( Plugin )
				# Simulate a named class, since we're not really requiring
				Plugin.derivatives['dazzle'] = loaded_class 
				true
			end

			Plugin.create( 'dazzle' ).should be_an_instance_of( loaded_class )
		end


		it "will output a sensible description of what it tried to load if requiring a " +
			"derivative fails" do

			# at least 6 -> 3 variants * 2 paths
			Plugin.should_receive( :require ).
				at_least(6).times.
				and_return {|path| raise LoadError, "path" }

			lambda { Plugin.create('scintillating') }.
				should raise_error( FactoryError, /couldn't find a \S+ named \S+.*tried \[/i )
		end


		it "will output a sensible description when a require succeeds, but it loads something unintended" do
			# at least 6 -> 3 variants * 2 paths
			Plugin.should_receive( :require ).and_return( true )

			lambda { Plugin.create('corruscating') }.
				should raise_error( FactoryError, /Require of '\S+' succeeded, but didn't load a Plugin/i )
		end


		it "will re-raise the first exception raised when attempting to load a " +
			"derivative if none of the paths work" do

			# at least 6 -> 3 variants * 2 paths
			Plugin.should_receive( :require ).at_least(6).times.and_return {|path|
				raise ScriptError, "error while parsing #{path}"
			}

			lambda { Plugin.create('portable') }.
				should raise_error( ScriptError, /error while parsing/ )
		end
	end


	context "derivative of an extended class" do

		it "knows what type of factory loads it" do
			TestingPlugin.factory_type.should == 'Plugin'
		end

		it "raises a FactoryError if it can't figure out what type of factory loads it" do
			TestingPlugin.stub!( :ancestors ).and_return( [] )
			lambda { TestingPlugin.factory_type }.
				should raise_error( FactoryError, /couldn't find factory base/i )
		end
	end


	context "derivative of an extended class that isn't named <Something>Plugin" do

		it "is still creatable via its full name" do
			Plugin.create( 'blacksheep' ).should be_an_instance_of( BlackSheep )
		end

	end


	context "derivative of an extended class in another namespace" do

		it "is still creatable via its derivative name" do
			Plugin.create( 'loadable' ).should be_an_instance_of( Test::LoadablePlugin )
		end

	end

end

