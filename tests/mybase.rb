#!/usr/bin/env ruby

require "pluginfactory"

class MyBase
	include PluginFactory
	def derivativeDirs 
		[".", "dir"].map {|dir|
			File.join(File.dirname(__FILE__), dir)
		}
	end
end
