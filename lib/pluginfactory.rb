#!/usr/bin/env ruby -w

require 'logger'

### An exception class for PluginFactory specific errors.
class FactoryError < RuntimeError; end

# This module contains the PluginFactory mixin. Including PluginFactory in your
# class turns it into a factory for its derivatives, capable of searching for
# and loading them by name. This is useful when you have an abstract base class
# which defines an interface and basic functionality for a part of a larger
# system, and a collection of subclasses which implement the interface for
# different underlying functionality.
#
# An example of where this might be useful is in a program which talks to a
# database. To avoid coupling it to a specific database, you use a Driver class
# which encapsulates your program's interaction with the database behind a
# useful interface. Now you can create a concrete implementation of the Driver
# class for each kind of database you wish to talk to. If you make the base
# Driver class a PluginFactory, too, you can add new drivers simply by dropping
# them in a directory and using the Driver's <tt>create</tt> method to
# instantiate them:
#
# == Creation Argument Variants
#
# The +create+ class method added to your class by PluginFactory searches for your module using
#
# == Synopsis
#
# in driver.rb:
#
#	require "PluginFactory"
#
#	class Driver
#		include PluginFactory
#		def self::derivative_dirs
#		   ["drivers"]
#		end
#	end
#
# in drivers/mysql.rb:
#
#	require 'driver'
#
#	class MysqlDriver < Driver
#		...implementation...
#	end
#
# in /usr/lib/ruby/1.8/PostgresDriver.rb:
#
#	require 'driver'
#
#	class PostgresDriver < Driver
#		...implementation...
#	end
#
# elsewhere
#
#	require 'driver'
#
#	config[:driver_type] #=> "mysql"
#	driver = Driver.create( config[:driver_type] )
#	driver.class #=> MysqlDriver
#	pgdriver = Driver.create( "PostGresDriver" )
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
# * Michael Granger <ged@FaerieMUD.org>
#
# == License
#
# Copyright (c) 2008-2012 Michael Granger and Martin Chase
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#
#   * Neither the name of the author/s, nor the names of the project's
#     contributors may be used to endorse or promote products derived from this
#     software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
module PluginFactory

	# Library version
	VERSION = '1.0.7'


	### Logging
	@default_logger = Logger.new( $stderr )
	@default_logger.level = $DEBUG ? Logger::DEBUG : Logger::WARN

	@logger = @default_logger


	class << self
		# The logger that will be used when the logging subsystem is reset
		attr_accessor :default_logger

		# The logger that's currently in effect
		attr_accessor :logger
		alias_method :log, :logger
		alias_method :log=, :logger=
	end


	### Deprecated: use the Logger object at #log to manipulate logging instead of this
	### method.
	def self::logger_callback=( callback )
		if callback.nil?
			self.logger.formatter = nil
		else
			self.logger.formatter = lambda {|lvl, _, _, msg|
				callback.call(lvl.downcase.to_sym, msg)
				''
			}
		end
	end


	### Reset the global logger object to the default
	def self::reset_logger
		self.logger = self.default_logger
		self.logger.level = Logger::WARN
	end


	### Returns +true+ if the global logger has not been set to something other than
	### the default one.
	def self::using_default_logger?
		return self.logger == self.default_logger
	end


	### Inclusion callback -- extends the including class. This is here so you can
	### either 'include' or 'extend'.
	def self::included( klass )
		klass.extend( self )
	end


	### Add the @derivatives instance variable to including classes.
	def self::extend_object( obj )
		obj.instance_variable_set( :@derivatives, {} )
		super
	end


	#############################################################
	###	M I X I N   M E T H O D S
	#############################################################

	### Return the Hash of derivative classes, keyed by various versions of
	### the class name.
	def derivatives
		ancestors.each do |klass|
			if klass.instance_variables.include?( :@derivatives ) ||
			   klass.instance_variables.include?( "@derivatives" )
				return klass.instance_variable_get( :@derivatives )
			end
		end
	end


	### Returns the type name used when searching for a derivative.
	def factory_type
		base = nil
		self.ancestors.each do |klass|
			if klass.instance_variables.include?( :@derivatives ) ||
				klass.instance_variables.include?( "@derivatives" )
				base = klass
				break
			end
		end

		raise FactoryError, "Couldn't find factory base for #{self.name}" if
			base.nil?

		if base.name =~ /^.*::(.*)/
			return $1
		else
			return base.name
		end
	end
	alias_method :factoryType, :factory_type


	### Inheritance callback -- Register subclasses in the derivatives hash
	### so that ::create knows about them.
	def inherited( subclass )
		keys = [ subclass ]

		# If it's not an anonymous class, make some keys out of variants of its name
		if subclass.name
			simple_name = subclass.name.sub( /#<Class:0x[[:xdigit:]]+>::/i, '' )
			keys << simple_name << simple_name.downcase

			# Handle class names like 'FooBar' for 'Bar' factories.
			PluginFactory.log.debug "Inherited %p for %p-type plugins" % [ subclass, self.factory_type ]
			if subclass.name.match( /(?:.*::)?(\w+)(?:#{self.factory_type})/i )
				keys << Regexp.last_match[1].downcase
			else
				keys << subclass.name.sub( /.*::/, '' ).downcase
			end
		else
			PluginFactory.log.debug "  no name-based variants for anonymous subclass %p" % [ subclass ]
		end

		keys.compact.uniq.each do |key|
			PluginFactory.log.info "Registering %s derivative of %s as %p" %
				[ subclass.name, self.name, key ]
			self.derivatives[ key ] = subclass
		end

		super
	end


	### Returns an Array of registered derivatives
	def derivative_classes
		self.derivatives.values.uniq
	end
	alias_method :derivativeClasses, :derivative_classes


	### Given the <tt>class_name</tt> of the class to instantiate, and other
	### arguments bound for the constructor of the new object, this method
	### loads the derivative class if it is not loaded already (raising a
	### LoadError if an appropriately-named file cannot be found), and
	### instantiates it with the given <tt>args</tt>. The <tt>class_name</tt>
	### may be the the fully qualified name of the class, the class object
	### itself, or the unique part of the class name. The following examples
	### would all try to load and instantiate a class called "FooListener"
	### if Listener included Factory
	###   obj = Listener.create( 'FooListener' )
	###   obj = Listener.create( FooListener )
	###   obj = Listener.create( 'Foo' )
	def create( class_name, *args, &block )
		subclass = get_subclass( class_name )

		begin
			return subclass.new( *args, &block )
		rescue => err
			nicetrace = err.backtrace.reject {|frame| /#{__FILE__}/ =~ frame}
			msg = "When creating '#{class_name}': " + err.message
			Kernel.raise( err, msg, nicetrace )
		end
	end


	### Given a <tt>class_name</tt> like that of the first argument to
	### #create, attempt to load the corresponding class if it is not
	### already loaded and return the class object.
	def get_subclass( class_name )
		return self if ( self.name == class_name || class_name == '' )
		if class_name.is_a?( Class )
			return class_name if class_name <= self
			raise ArgumentError, "%s is not a descendent of %s" % [class_name, self]
		end

		class_name = class_name.to_s

		# If the derivatives hash doesn't already contain the class, try to load it
		unless self.derivatives.has_key?( class_name.downcase )
			self.load_derivative( class_name )

			subclass = self.derivatives[ class_name.downcase ]
			unless subclass.is_a?( Class )
				raise FactoryError,
					"load_derivative(%s) added something other than a class "\
					"to the registry for %s: %p" %
					[ class_name, self.name, subclass ]
			end
		end

		return self.derivatives[ class_name.downcase ]
	end
	alias_method :getSubclass, :get_subclass


	### Calculates an appropriate filename for the derived class using the
	### name of the base class and tries to load it via <tt>require</tt>. If
	### the including class responds to a method named
	### <tt>derivativeDirs</tt>, its return value (either a String, or an
	### array of Strings) is added to the list of prefix directories to try
	### when attempting to require a modules. Eg., if
	### <tt>class.derivativeDirs</tt> returns <tt>['foo','bar']</tt> the
	### require line is tried with both <tt>'foo/'</tt> and <tt>'bar/'</tt>
	### prepended to it.
	def load_derivative( class_name )
		PluginFactory.log.debug "Loading derivative #{class_name}"

		# Get the unique part of the derived class name and try to
		# load it from one of the derivative subdirs, if there are
		# any.
		mod_name = self.get_module_name( class_name )
		result = self.require_derivative( mod_name )

		# Check to see if the specified listener is now loaded. If it
		# is not, raise an error to that effect.
		unless self.derivatives[ class_name.downcase ]
			errmsg = "Require of '%s' succeeded, but didn't load a %s named '%s' for some reason." % [
				result,
				self.factory_type,
				class_name.downcase,
			]
			PluginFactory.log.error( errmsg )
			raise FactoryError, errmsg, caller(3)
		end
	end
	alias_method :loadDerivative, :load_derivative


	### Build and return the unique part of the given <tt>class_name</tt>
	### either by stripping leading namespaces if the name already has the
	### name of the factory type in it (eg., 'My::FooService' for Service,
	### or by appending the factory type if it doesn't.
	def get_module_name( class_name )
		if class_name =~ /\w+#{self.factory_type}/
			mod_name = class_name.sub( /(?:.*::)?(\w+)(?:#{self.factory_type})/, "\\1" )
		else
			mod_name = class_name
		end

		return mod_name
	end
	alias_method :getModuleName, :get_module_name


	### If the factory responds to the #derivative_dirs method, call
	### it and use the returned array as a list of directories to
	### search for the module with the specified <tt>mod_name</tt>.
	def require_derivative( mod_name )

		# See if we have a list of special subdirs that derivatives
		# live in
		if ( self.respond_to?(:derivative_dirs) )
			subdirs = self.derivative_dirs

		elsif ( self.respond_to?(:derivativeDirs) )
			subdirs = self.derivativeDirs

		# If not, just try requiring it from $LOAD_PATH
		else
			subdirs = ['']
		end

		subdirs = [ subdirs ] unless subdirs.is_a?( Array )
		PluginFactory.log.debug "Subdirs are: %p" % [subdirs]
		fatals = []
		tries  = []

		# Iterate over the subdirs until we successfully require a
		# module.
		subdirs.collect {|dir| dir.strip}.each do |subdir|
			self.make_require_path( mod_name, subdir ).each do |path|
				PluginFactory.log.debug "Trying #{path}..."
				tries << path

				# Try to require the module, saving errors and jumping
				# out of the catch block on success.
				begin
					require( path.untaint )
				rescue LoadError => err
					PluginFactory.log.debug "No module at '%s', trying the next alternative: '%s'" %
						[ path, err.message ]
				rescue Exception => err
					fatals << err
					PluginFactory.log.error "Found '#{path}', but encountered an error: %s\n\t%s" %
						[ err.message, err.backtrace.join("\n\t") ]
				else
					PluginFactory.log.info "Loaded '#{path}' without error."
					return path
				end
			end
		end

		PluginFactory.log.debug "fatals = %p" % [ fatals ]

		# Re-raise is there was a file found, but it didn't load for
		# some reason.
		if fatals.empty?
			errmsg = "Couldn't find a %s named '%s': tried %p" % [
				self.factory_type,
				mod_name,
				tries
			  ]
			PluginFactory.log.error( errmsg )
			raise FactoryError, errmsg
		else
			PluginFactory.log.debug "Re-raising first fatal error"
			Kernel.raise( fatals.first )
		end
	end
	alias_method :requireDerivative, :require_derivative


	### Make a list of permutations of the given +modname+ for the given
	### +subdir+. Called on a +DataDriver+ class with the arguments 'Socket' and
	### 'drivers', returns:
	###   ["drivers/socketdatadriver", "drivers/socketDataDriver",
	###    "drivers/SocketDataDriver", "drivers/socket", "drivers/Socket"]
	def make_require_path( modname, subdir )
		path = []
		myname = self.factory_type

		# Make permutations of the two parts
		path << modname
		path << modname.downcase
		path << modname			       + myname
		path << modname.downcase       + myname
		path << modname.downcase       + myname.downcase
		path << modname			 + '_' + myname
		path << modname.downcase + '_' + myname
		path << modname.downcase + '_' + myname.downcase

		# If a non-empty subdir was given, prepend it to all the items in the
		# path
		unless subdir.nil? or subdir.empty?
			path.collect! {|m| File.join(subdir, m)}
		end

		PluginFactory.log.debug "Path is: #{path.uniq.reverse.inspect}..."
		return path.uniq.reverse
	end
	alias_method :makeRequirePath, :make_require_path

end # module Factory
