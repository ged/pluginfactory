#!/usr/bin/env ruby

require "pluginfactory"

class MyBase
	include PluginFactory
	def self::derivativeDirs 
		testdir = File::expand_path( File.dirname(__FILE__) )
		return [ testdir, File::join(testdir, "dir") ]
	end
end
