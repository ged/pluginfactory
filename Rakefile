#!rake
#
# PluginFactory rakefile
#
# Based on various other Rakefiles, especially one by Ben Bleything
#
# Copyright (c) 2007-2008 The FaerieMUD Consortium
#
# Authors:
#  * Michael Granger <ged@FaerieMUD.org>
#

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname
	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}


require 'pluginfactory'

require 'rbconfig'
require 'rubygems'
require 'rake'
require 'rake/rdoctask'
require 'rake/testtask'
require 'rake/packagetask'

$dryrun = false

### Config constants
PKG_NAME      = 'PluginFactory'
PKG_SUMMARY   = 'A mixin module for creating plugin classes'
PKG_VERSION   = PluginFactory::VERSION
PKG_FILE_NAME = "#{PKG_NAME.downcase}-#{PKG_VERSION}"
GEM_FILE_NAME = "#{PKG_FILE_NAME}.gem"

RELEASE_NAME  = "RELEASE_#{PKG_VERSION.gsub(/\./, '_')}"

BASEDIR       = Pathname.new( __FILE__ ).dirname.relative_path_from( Pathname.getwd )
LIBDIR        = BASEDIR + 'lib'
DOCSDIR       = BASEDIR + 'docs'
PKGDIR        = BASEDIR + 'pkg'

ARTIFACTS_DIR = Pathname.new( ENV['CC_BUILD_ARTIFACTS'] || '' )

TEXT_FILES    = %w( Rakefile ChangeLog README LICENSE ).
	collect {|filename| BASEDIR + filename }
LIB_FILES     = Pathname.glob( LIBDIR + '**/*.rb').
	delete_if {|item| item =~ /\.svn/ }

SPECDIR       = BASEDIR + 'spec'
SPEC_FILES    = Pathname.glob( SPECDIR + '**/*_spec.rb' ).
	delete_if {|item| item =~ /\.svn/ }
SPEC_EXCLUDES = 'spec,/Library/Ruby,/var/lib,/usr/local/lib'


RELEASE_FILES = TEXT_FILES + SPEC_FILES + LIB_FILES

# Load task plugins
RAKE_TASKDIR = BASEDIR + 'rake'
Pathname.glob( RAKE_TASKDIR + '*.rb' ).each do |tasklib|
	require tasklib
end

# Define some constants that depend on the 'svn' tasklib
PKG_BUILD = get_svn_rev( BASEDIR ) || 0
SNAPSHOT_PKG_NAME = "#{PKG_FILE_NAME}.#{PKG_BUILD}"
SNAPSHOT_GEM_NAME = "#{SNAPSHOT_PKG_NAME}.gem"

# Documentation constants
RDOC_OPTIONS = [
	'-w', '4',
	'-SHN',
	'-i', '.',
	'-m', 'README',
	'-W', 'http://deveiate.org/projects/PluginFactory/browser/trunk/'
  ]

# Release constants
SMTP_HOST = 'mail.faeriemud.org'
SMTP_PORT = 465 # SMTP + SSL

# Project constants
PROJECT_HOST = 'deveiate.org'
PROJECT_PUBDIR = "/usr/local/www/public/code"
PROJECT_DOCDIR = "#{PROJECT_PUBDIR}/#{PKG_NAME}"
PROJECT_SCPURL = "#{PROJECT_HOST}:#{PROJECT_DOCDIR}"

# RubyGem specification
GEMSPEC   = Gem::Specification.new do |gem|
	gem.name              = PKG_NAME.downcase
	gem.version           = PKG_VERSION

	gem.summary           = PKG_SUMMARY
	gem.description       = <<-EOD
	PluginFactory is a mixin module that adds pluggable behavior to including
	classes, allowing you to require and instantiate its subclasses by name via a 
	factory method.
	EOD

	gem.authors           = "Michael Granger, Martin Chase"
	gem.email             = 'ged@FaerieMUD.org'
	gem.homepage          = "http://deveiate.org/projects/PluginFactory"
	gem.rubyforge_project = 'deveiate'

	gem.has_rdoc          = true
	gem.rdoc_options      = RDOC_OPTIONS

	gem.files             = RELEASE_FILES.
		collect {|f| f.relative_path_from(BASEDIR).to_s }
	gem.test_files        = SPEC_FILES.
		collect {|f| f.relative_path_from(BASEDIR).to_s }
end



if Rake.application.options.trace
	$trace = true
	log "$trace is enabled"
end

if Rake.application.options.dryrun
	$dryrun = true
	log "$dryrun is enabled"
end

### Default task
task :default  => [:clean, :spec, :rdoc, :package]


### Task: clean
desc "Clean pkg, coverage, and rdoc; remove .bak files"
task :clean => [ :clobber_rdoc, :clobber_package ] do
	files = FileList['**/*.bak']
	files.clear_exclude
	File.rm( files ) unless files.empty?
	FileUtils.rm_rf( 'artifacts' )
end


begin
	gem 'darkfish-rdoc'

	Rake::RDocTask.new do |rdoc|
		rdoc.rdoc_dir = 'docs'
		rdoc.title    = "#{PKG_NAME} - #{PKG_SUMMARY}"
		rdoc.options += RDOC_OPTIONS + [ '-f', 'darkfish' ]

		rdoc.rdoc_files.include 'README'
		rdoc.rdoc_files.include LIB_FILES.collect {|f| f.to_s }
	end
rescue LoadError, Gem::Exception => err
	if !Object.const_defined?( :Gem )
		require 'rubygem'
		retry
	end
	
	task :no_darkfish do
		fail "Could not generate RDoc: %s" % [ err.message ]
	end
	task :docs => :no_darkfish
end


### Task: package
Rake::PackageTask.new( PKG_NAME, PKG_VERSION ) do |task|
  	task.need_tar_gz   = true
	task.need_tar_bz2  = true
	task.need_zip      = true
	task.package_dir   = PKGDIR.to_s
  	task.package_files = RELEASE_FILES.
		collect {|f| f.relative_path_from(BASEDIR).to_s }
end
task :package => [:gem]


### Task: gem
gempath = PKGDIR + GEM_FILE_NAME

desc "Build a RubyGem package (#{GEM_FILE_NAME})"
task :gem => gempath.to_s
file gempath.to_s => [PKGDIR.to_s] + GEMSPEC.files do
	when_writing( "Creating GEM" ) do
		Gem::Builder.new( GEMSPEC ).build
		verbose( true ) do
			mv GEM_FILE_NAME, gempath
		end
	end
end

### Task: install
desc "Install PluginFactory as a conventional library"
task :install do
	log "Installing PluginFactory as a conventional library"
	sitelib = Pathname.new( CONFIG['sitelibdir'] )
	Dir.chdir( LIBDIR ) do
		LIB_FILES.each do |libfile|
			relpath = libfile.relative_path_from( LIBDIR )
			target = sitelib + relpath
			FileUtils.mkpath target.dirname,
				:mode => 0755, :verbose => true, :noop => $dryrun unless target.dirname.directory?
			FileUtils.install relpath, target,
				:mode => 0644, :verbose => true, :noop => $dryrun
		end
	end
end



### Task: install_gem
desc "Install PluginFactory from a locally-built gem"
task :install_gem => [:package] do
	$stderr.puts 
	installer = Gem::Installer.new( %{pkg/#{PKG_FILE_NAME}.gem} )
	installer.install
end

### Task: uninstall_gem
desc "Install the PluginFactory gem"
task :uninstall_gem => [:clean] do
	uninstaller = Gem::Uninstaller.new( PKG_FILE_NAME )
	uninstaller.uninstall
end



### Cruisecontrol task
desc "Cruisecontrol build"
task :cruise => [:clean, :spec, :package] do |task|
	raise "Artifacts dir not set." if ARTIFACTS_DIR.to_s.empty?
	artifact_dir = ARTIFACTS_DIR.cleanpath
	artifact_dir.mkpath
	
	$stderr.puts "Copying coverage stats..."
	FileUtils.cp_r( 'coverage', artifact_dir )
	
	$stderr.puts "Copying packages..."
	FileUtils.cp_r( FileList['pkg/*'].to_a, artifact_dir )
end


### RSpec tasks
begin
	gem 'rspec', '>= 1.0.5'
	require 'spec/rake/spectask'

	### Task: spec
	Spec::Rake::SpecTask.new( :spec ) do |task|
		task.spec_files = SPEC_FILES
		task.libs += [LIBDIR]
		task.spec_opts = ['-c', '-f','s', '-b', '-D', 'u']
	end
	task :test => [:spec]


	namespace :spec do

		desc "Run rspec every time there's a change to one of the files"
        task :autotest do
			gem 'ZenTest', ">= 3.6.0"
            require 'autotest/rspec'
            autotester = Autotest::Rspec.new
			autotester.exceptions = %r{\.svn|\.skel}
            autotester.test_mappings = {
                %r{^spec/.*\.rb$} => proc {|filename, _|
                    filename
                },
                %r{^lib/[^/]*\.rb$} => proc {|_, m|
                    ["spec/#{m[1]}_spec.rb"]
                },
            }
            
            autotester.run
        end

	
		desc "Generate HTML output for a spec run"
		Spec::Rake::SpecTask.new( :html ) do |task|
			task.spec_files = SPEC_FILES
			task.spec_opts = ['-f','h', '-D']
		end

		desc "Generate plain-text output for a CruiseControl.rb build"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES
			task.spec_opts = ['-f','p']
		end
	end
rescue LoadError => err
	task :no_rspec do
		$stderr.puts "Testing tasks not defined: RSpec rake tasklib not available: %s" %
			[ err.message ]
	end
	
	task :spec => :no_rspec
	namespace :spec do
		task :autotest => :no_rspec
		task :html => :no_rspec
		task :text => :no_rspec
	end
end


RCOV_OPTS = [
	'--exclude', SPEC_EXCLUDES,
	'--xrefs',
	'--save',
	'--callsites'
  ]

### RCov (via RSpec) tasks
begin
	gem 'rcov', '>= 0.8.0.1'
	gem 'rspec', '>= 1.0.5'

	### Task: coverage (via RCov)
	### Task: spec
	desc "Build test coverage reports"
	Spec::Rake::SpecTask.new( :coverage ) do |task|
		task.spec_files = SPEC_FILES
		task.libs += [LIBDIR]
		task.spec_opts = ['-f', 'p', '-b']
		task.rcov_opts = RCOV_OPTS
		task.rcov = true
	end

	task :rcov => [:coverage] do; end
	

	### Other coverage tasks
	namespace :coverage do
		desc "Generate a detailed text coverage report"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES
			task.rcov_opts = RCOV_OPTS + ['--text-coverage']
			task.rcov = true
		end

		desc "Show differences in coverage from last run"
		Spec::Rake::SpecTask.new( :diff ) do |task|
			task.spec_files = SPEC_FILES
			task.rcov_opts = ['--text-coverage-diff']
			task.rcov = true
		end

		### Task: verify coverage
		desc "Build coverage statistics"
		VerifyTask.new( :verify => :rcov ) do |task|
			task.threshold = 85.0
		end
	end


rescue LoadError => err
	task :no_rcov do
		$stderr.puts "Coverage tasks not defined: RSpec+RCov tasklib not available: %s" %
			[ err.message ]
	end

	task :coverage => :no_rcov
	task :clobber_coverage
	task :rcov => :no_rcov
	namespace :coverage do
		task :text => :no_rcov
		task :diff => :no_rcov
	end
	task :verify => :no_rcov
end


