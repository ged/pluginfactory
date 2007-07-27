#!rake
#
# PluginFactory rakefile
#
# Based on various other Rakefiles, especially one by Ben Bleything
#
# Copyright (c) 2007 The FaerieMUD Consortium
#
# Mistakes:
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
require 'rake/gempackagetask'

$dryrun = false

### Config constants
PKG_NAME      = 'PluginFactory'
PKG_SUMMARY   = 'A mixin module for creating plugin classes'
PKG_VERSION   = PluginFactory::VERSION
PKG_FILE_NAME = "#{PKG_NAME.downcase}-#{PKG_VERSION}"

RELEASE_NAME  = "REL #{PKG_VERSION}"

BASEDIR       = Pathname.new( __FILE__ ).dirname.expand_path
LIBDIR        = BASEDIR + 'lib'
DOCSDIR       = BASEDIR + 'docs'
SPECDIR       = BASEDIR + 'spec'

ARTIFACTS_DIR = Pathname.new( ENV['CC_BUILD_ARTIFACTS'] || '' )

TEXT_FILES    = %w( Rakefile ChangeLog README LICENSE ).
	collect {|filename| BASEDIR + filename }
SPEC_FILES    = Pathname.glob( SPECDIR + '**/*_spec.rb' ).
	delete_if {|item| item =~ /\.svn/ }
LIB_FILES     = Pathname.glob( LIBDIR + '**/*.rb').
	delete_if {|item| item =~ /\.svn/ }

RELEASE_FILES = TEXT_FILES + LIB_FILES

# Load task plugins
RAKE_TASKDIR = BASEDIR + 'rake'
Pathname.glob( RAKE_TASKDIR + '*.rb' ).each do |tasklib|
	require tasklib
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


### Task: rdoc
Rake::RDocTask.new do |rdoc|
	rdoc.rdoc_dir = 'docs/api'
	rdoc.title    = "#{PKG_NAME} - #{PKG_SUMMARY}"
	rdoc.options += ['-w', '4', '-SHN', '-i', 'docs']

	rdoc.rdoc_files.include 'README'
	rdoc.rdoc_files.include LIB_FILES.collect {|f| f.to_s }
end



### Task: gem
gemspec = Gem::Specification.new do |gem|
	pkg_build = get_svn_rev( BASEDIR ) || 0
	
	gem.name    	= PKG_NAME.downcase
	gem.version 	= "%s.%s" % [ PKG_VERSION, pkg_build ]

	gem.summary     = "#{PKG_NAME} - #{PKG_SUMMARY}"
	gem.description = <<-EOD
	PluginFactory is a mixin module that adds plugin-like behavior to the including
	class, allowing you to require and instantiate its subclasses by name via a 
	.create factory method.
	EOD

	gem.authors  	= "Martin Chase <stillflame@FaerieMUD.org> and " +
					  "Michael Granger <ged@FaerieMUD.org>"
	gem.homepage 	= "http://deveiate.org/projects/PluginFactory"

	gem.has_rdoc 	= true

	gem.files      	= RELEASE_FILES.
		collect {|f| f.relative_path_from(BASEDIR).to_s }
	gem.test_files 	= SPEC_FILES.
		collect {|f| f.relative_path_from(BASEDIR).to_s }
end
Rake::GemPackageTask.new( gemspec ) do |task|
	task.gem_spec = gemspec
	task.need_tar = false
	task.need_tar_gz = true
	task.need_tar_bz2 = true
	task.need_zip = true
end


### Task: install
task :install => [:package] do
	$stderr.puts 
	installer = Gem::Installer.new( %{pkg/#{PKG_FILE_NAME}.gem} )
	installer.install
end

### Task: uninstall
task :uninstall => [:clean] do
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
	'--exclude', 'spec',
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


