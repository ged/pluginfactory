# -*- ruby -*-
#
# PluginFactory RubyGems specification
# $Id$
#

BEGIN {
	$basedir = File::dirname( File::expand_path(__FILE__) )
}

require 'date'
require 'rubygems'
require "#$basedir/utils.rb"
include UtilityFunctions

spec = Gem::Specification.new do |s|
	s.name = extractProjectName()
	s.version = extractVersion().join('.')
	s.date = Date.today.to_s
	s.platform = Gem::Platform::RUBY
	s.summary = "Mixin module that adds plugin behavior to any class"
	s.description = %q{PluginFactory is a module that provides plugin behavior for any class. Including PluginFactory in your class provides a ::create class method, which can be passed the name of any derivatives. Derivative classes are loaded dynamically and instantiated by the factory class.}
	s.files = getVettedManifest()
	s.require_path = 'lib'
	s.autorequire = 'pluginfactory'
	s.has_rdoc = true
	s.rdoc_options = ['--main', 'README']
	s.extra_rdoc_files = ['README']
	s.author = "Michael Granger"
	s.email = "ged@FaerieMUD.org"
	s.homepage = "http://www.devEiate.org/code/PluginFactory.html"
	s.test_file = 'test.rb'
	s.required_ruby_version = Gem::Version::Requirement.new(">= 1.8.0")
end

if $0==__FILE__
	p spec
	Gem.manage_gems
	Gem::Builder.new(spec).build
end
