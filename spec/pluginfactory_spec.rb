#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'pluginfactory'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end



class Plugin
	extend PluginFactory
	def self::derivative_dirs 
		[ 'plugins', 'plugins/private' ]
	end
end



describe PluginFactory do

	it "calls its logging callback with the level and joined message if set" do
		level = nil; msg = nil
		PluginFactory.logger_callback = lambda {|l, m| level = l; msg = m }
		
		PluginFactory.log( :level, 'message1', 'message2' )
		level.should == :level
		msg.should == 'message1message2'
	end
	
	it "doesn't error when its log method is called if no logging callback is set" do
		PluginFactory.logger_callback = nil
		lambda { PluginFactory.log(:level, "msg") }.should_not raise_error()
	end

end

describe "A class extended with PluginFactory" do
	
	before( :each ) do
		# This is kind of cheating, but it makes testing possible without knowing 
		# the order the examples are run in
		Plugin.derivatives.clear
	end
	
	
	it "knows about all of its derivatives" do
		Plugin.derivatives.should be_empty()
		Plugin.derivatives.should be_an_instance_of( Hash )
		
		class SubPlugin < Plugin; end
		
		Plugin.derivatives.should have(4).members
		Plugin.derivatives.keys.should include( 'sub' )
		Plugin.derivatives.keys.should include( 'subplugin' )
		Plugin.derivatives.keys.should include( 'SubPlugin' )
		Plugin.derivatives.keys.should include( SubPlugin )
	end
	
	it "can return an Array of all of its derivative classes" do
		Plugin.derivative_classes.should be_empty()
		
		class OtherPlugin < Plugin; end
		
		Plugin.derivative_classes.should == [OtherPlugin]
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

		Plugin.should_receive( :require ).and_return {|*args|
			loaded_class = Class.new( Plugin ) do
				def self::name; "DazzlePlugin"; end
			end
			true
		}
		
		Plugin.create( 'dazzle' ).should be_an_instance_of( loaded_class )
	end
	

	it "will #require derivatives that aren't yet loaded" do
		loaded_class = nil

		Plugin.should_receive( :require ).and_return {|*args|
			loaded_class = Class.new( Plugin ) do
				def self::name; "SnazzlePlugin"; end
			end
			true
		}
		
		Plugin.create( 'snazzle' ).should be_an_instance_of( loaded_class )
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


describe "A derivative of a class extended with PluginFactory" do
	
	before( :all ) do
		class TestingPlugin < Plugin; end
	end
	
	it "knows what type of factory loads it" do
		TestingPlugin.factory_type.should == 'Plugin'
	end

	it "raises a FactoryError if it can't figure out what type of factory loads it" do
		TestingPlugin.stub!( :ancestors ).and_return( [] )
		lambda { TestingPlugin.factory_type }.
			should raise_error( FactoryError, /couldn't find factory base/i )
	end
end


describe "A derivative of a class extended with PluginFactory that isn't named <Something>Plugin" do
	
	before( :all ) do
		class BlackSheep < Plugin; end
	end
	
	it "is still creatable via its full name" do
		Plugin.create( 'blacksheep' ).should be_an_instance_of( BlackSheep )
	end
	
end


describe "A derivative of a class extended with PluginFactory in another namespace" do
	
	before( :all ) do
		module Test
			class LoadablePlugin < Plugin; end
		end
	end
	
	it "is still creatable via its derivative name" do
		Plugin.create( 'loadable' ).should be_an_instance_of( Test::LoadablePlugin )
	end
	
end

