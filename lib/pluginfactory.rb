#!/usr/bin/env ruby -w
#
# [<tt>PluginFactory</tt>]
#    A mixin that adds Factory design pattern-like behaviour to the including
#    class.  Autoloads files based on class name.
#
# == Synopsis
# 
#---##### in myclass.rb #####---
# 
#	require "PluginFactory"
#
#	class MyClass
#		include PluginFactory
#		def derivativeDirs() ["some/dir"] end
#	end
# 
#---##########
#
#---##### in some/dir/mysubclass.rb #####
# 
#	require 'myclass'
#
#	class MySubClass < MyClass; end
# 
#---##########
#
#---##### in /lib/ruby/othersub.rb #####
# 
#	require 'myclass'
#
#	class OtherSubClass < MyClass; end
# 
#---##########
#
#---##### elsewhere #####
# 
#	require 'myclass'
#
#	foo = MyClass.create("MySub")
#	foo.class #=> MySubClass
#	bar = MyClass.create("OtherSubClass")
# 
#---##########
# 
# == Rcsid
# 
# $Id: pluginfactory.rb,v 1.2 2004/03/07 18:49:23 stillflame Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file docs/COPYRIGHT for licensing details.
#


### An exception class for PluginFactory specific errors.
class FactoryError < Exception
	def initialize( *args )
		if ! args.empty?
			msg = args.collect {|a| a.to_s}.join
			super( msg )
		else
			super( message )
		end					
	end
end # class FactoryError


### A mixin that adds PluginFactory class methods to a base class, so that
### subclasses may be instantiated by name.
module PluginFactory

	class << self


		### A callback for logging the various debug and information this module
		### has to log.  Should take two arguments, the log level, possibly as a
		### symbol, and the log message itself.
		attr_accessor :logger_callback


		### If the logger callback is set, use it to pass on a log entry.  First argument is 
		def log(level, *msg)
			@logger_callback.call(level, msg.join) if @logger_callback
		end


		### Inclusion callback -- extends the including class.
		def included( klass )
			klass.extend( self )
		end


		### Raise an exception if the object being extended is anything but a
		### class.
		def extend_object( obj )
			unless obj.is_a?( Class )
				raise TypeError, "Cannot extend a #{obj.class.name}", caller(1)
			end
			obj.instance_variable_set( :@derivatives, {} )
			super
		end

	end # class << self

	#############################################################
	###	M I X I N   M E T H O D S
	#############################################################

	### Return the Hash of derivative classes, keyed by various versions of
	### the class name.
	def derivatives
		ancestors.each {|klass|
			if klass.instance_variables.include?( "@derivatives" )
				break klass.instance_variable_get( :@derivatives )
			end
		}
	end


	### Returns the type name used when searching for a derivative.
	def factoryType
		base = nil
		self.ancestors.each {|klass|
			if klass.instance_variables.include?( "@derivatives" )
				base = klass
				break
			end
		}

		raise FactoryError, "Couldn't find factory base for #{self.name}" if
			base.nil?

		if base.name =~ /^.*::(.*)/
			return $1
		else
			return base.name
		end
	end

	
	### Inheritance callback -- Register subclasses in the derivatives hash
	### so that ::create knows about them.
	def inherited( subclass )
		truncatedName =
			# Handle class names like 'FooBar' for 'Bar' factories.
			if subclass.name.match( /(?:.*::)?(\w+)(?:#{self.factoryType})/ )
				Regexp.last_match[1].downcase
			else
				subclass.name.sub( /.*::/, '' ).downcase
			end

		PluginFactory.log :info, "Registering %s derivative of %s as %s" %
			[ subclass.name, self.name, truncatedName ]
		[ subclass.name, truncatedName, subclass ].each {|key|
			self.derivatives[ key ] = subclass
		}
		super
	end


	### Returns an Array of registered derivatives
	def derivativeClasses
		self.derivatives.values.uniq
	end


	### Given the <tt>className</tt> of the class to instantiate, and other
	### arguments bound for the constructor of the new object, this method
	### loads the derivative class if it is not loaded already (raising a
	### LoadError if an appropriately-named file cannot be found), and
	### instantiates it with the given <tt>args</tt>. The <tt>className</tt>
	### may be the the fully qualified name of the class, the class object
	### itself, or the unique part of the class name. The following examples
	### would all try to load and instantiate a class called "FooListener"
	### if Listener included Factory
	###   obj = Listener::create( 'FooListener' )
	###   obj = Listener::create( FooListener )
	###   obj = Listener::create( 'Foo' )
	def create( subType, *args, &block )
		subclass = getSubclass( subType )

		return subclass.new( *args, &block )
	rescue => err
		nicetrace = err.backtrace.reject {|frame| /#{__FILE__}/ =~ frame}
		msg = "When creating '#{subType}': " + err.message
		Kernel::raise( err.class, msg, nicetrace )
	end


	### Given a <tt>className</tt> like that of the first argument to
	### #create, attempt to load the corresponding class if it is not
	### already loaded and return the class object.
	def getSubclass( className )
		return self if ( self.name == className || className == '' )
		return className if className.is_a?( Class ) && className >= self

		unless self.derivatives.has_key?( className.downcase )

			self.loadDerivative( className )

			unless self.derivatives.has_key?( className.downcase )
				raise FactoryError,
					"loadDerivative(%s) didn't add a '%s' key to the "\
				"registry for %s" %
					[ className, className.downcase, self.name ]
			end
			unless self.derivatives[className].is_a?( Class )
				raise FactoryError,
					"loadDerivative(%s) added something other than a class "\
				"to the registry for %s" % [ className, self.name ]
			end
		end

		return self.derivatives[ className.downcase ]
	end


	### Calculates an appropriate filename for the derived class using the
	### name of the base class and tries to load it via <tt>require</tt>. If
	### the including class responds to a method named
	### <tt>derivativeDirs</tt>, its return value (either a String, or an
	### array of Strings) is added to the list of prefix directories to try
	### when attempting to require a modules. Eg., if
	### <tt>class.derivativeDirs</tt> returns <tt>['foo','bar']</tt> the
	### require line is tried with both <tt>'foo/'</tt> and <tt>'bar/'</tt>
	### prepended to it.
	def loadDerivative( className )
		className = className.to_s

		# Get the unique part of the derived class name and try to
		# load it from one of the derivative subdirs, if there are
		# any.
		modName = self.getModuleName( className )
		self.requireDerivative( modName )

		# Check to see if the specified listener is now loaded. If it
		# is not, raise an error to that effect.
		unless self.derivatives[ className.downcase ]
			raise RuntimeError,
				"Couldn't find a %s named '%s'. Loaded derivatives are: %p" % [
				self.factoryType,
				className.downcase,
				self.derivatives.keys,
			], caller(3)
		end

		return true
	end


	### Build and return the unique part of the given <tt>className</tt>
	### either by stripping leading namespaces if the name already has the
	### name of the factory type in it (eg., 'My::FooService' for Service,
	### or by appending the factory type if it doesn't.
	def getModuleName( className )
		if className =~ /\w+#{self.factoryType}/
			modName = className.sub( /(?:.*::)?(\w+)(?:#{self.factoryType})/, "\\1" )
		else
			modName = className
		end

		return modName
	end


	### If the factory responds to the #derivativeDirs method, call
	### it and use the returned array as a list of directories to
	### search for the module with the specified <tt>modName</tt>.
	def requireDerivative( modName )

		# See if we have a list of special subdirs that derivatives
		# live in
		if ( self.respond_to?(:derivativeDirs) )
			subdirs = self.derivativeDirs
			subdirs = [ subdirs ] unless subdirs.is_a?( Array )

			# If not, just try requiring it from $LOAD_PATH
		else
			subdirs = ['']
		end

		fatals = []

		# Iterate over the subdirs until we successfully require a
		# module.
		catch( :found ) {
			subdirs.collect {|dir| dir.strip}.each do |subdir|
				modPath = if subdir.empty? then modName
						  else File::join( subdir, modName )
						  end
				lcModPath = if subdir.empty? then modName.downcase
							else lcModPath = File::join( subdir, modName.downcase )
							end
				altModPath = modPath + self.factoryType.downcase
				lcAltModPath = lcModPath + self.factoryType.downcase

				[modPath, lcModPath, altModPath, lcAltModPath].uniq.each {|path|
					#PluginFactory.log :debug, "Trying #{path}..."

					# Try to require the module that defines the specified
					# derivative
					begin
						require( path.untaint )
					rescue LoadError => err
						PluginFactory.log :debug,
						"No module at '%s', trying the next alternative: '%s'" %
							[ path, err.message ]
					rescue ScriptError,StandardError => err
						fatals << err
						PluginFactory.log :error,
						"Found '#{path}', but encountered an error: %s\n\t%s" %
							[ err.message, err.backtrace.join("\n\t") ]
					else
						#PluginFactory.log :debug,
						#	"Found '#{path}'. Throwing :found"
						throw :found
					end
				}
			end

			#PluginFactory.log :debug, "fatals = %p" % [ fatals ]

			# Re-raise is there was a file found, but it didn't load for
			# some reason.
			if ! fatals.empty?
				#PluginFactory.log :debug, "Re-raising first fatal error"
				Kernel::raise( fatals.first )
			end

			nil
		}
	end
end # module Factory
