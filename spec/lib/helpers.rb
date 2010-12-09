#!/usr/bin/ruby
# coding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'rspec'
require 'pluginfactory'


### RSpec helper functions.
module PluginFactory

	# An alternate formatter for Logger instances that outputs +div+ HTML
	# fragments.
	# @private
	class HtmlLogFormatter < Logger::Formatter
		include ERB::Util  # for html_escape()

		# The default HTML fragment that'll be used as the template for each log message.
		HTML_LOG_FORMAT = %q{
		<div class="log-message %5$s">
			<span class="log-time">%1$s.%2$06d</span>
			[
				<span class="log-pid">%3$d</span>
				/
				<span class="log-tid">%4$s</span>
			]
			<span class="log-level">%5$s</span>
			:
			<span class="log-name">%6$s</span>
			<span class="log-message-text">%7$s</span>
		</div>
		}

		### Override the logging formats with ones that generate HTML fragments
		def initialize( logger, format=HTML_LOG_FORMAT ) # :notnew:
			@logger = logger
			@format = format
			super()
		end


		######
		public
		######

		# The HTML fragment that will be used as a format() string for the log
		attr_accessor :format


		### Return a log message composed out of the arguments formatted using the
		### formatter's format string
		def call( severity, time, progname, msg )
			args = [
				time.strftime( '%Y-%m-%d %H:%M:%S' ),                         # %1$s
				time.usec,                                                    # %2$d
				Process.pid,                                                  # %3$d
				Thread.current == Thread.main ? 'main' : Thread.object_id,    # %4$s
				severity.downcase,                                                     # %5$s
				progname,                                                     # %6$s
				html_escape( msg ).gsub(/\n/, '<br />')                       # %7$s
			]

			return self.format % args
		end

	end # class HtmlLogFormatter


	### Spec helper functions
	module SpecHelpers

		class ArrayLogger
			### Create a new ArrayLogger that will append content to +array+.
			def initialize( array )
				@array = array
			end

			### Write the specified +message+ to the array.
			def write( message )
				@array << message
			end

			### No-op -- this is here just so Logger doesn't complain
			def close; end

		end # class ArrayLogger


		unless defined?( LEVEL )
			LEVEL = {
				:debug => Logger::DEBUG,
				:info  => Logger::INFO,
				:warn  => Logger::WARN,
				:error => Logger::ERROR,
				:fatal => Logger::FATAL,
			  }
		end

		###############
		module_function
		###############

		### Make an easily-comparable version vector out of +ver+ and return it.
		def vvec( ver )
			return ver.split('.').collect {|char| char.to_i }.pack('N*')
		end


		### Reset the logging subsystem to its default state.
		def reset_logging
			PluginFactory.reset_logger
		end


		### Alter the output of the default log formatter to be pretty in SpecMate output
		def setup_logging( level=Logger::FATAL )

			# Turn symbol-style level config into Logger's expected Fixnum level
			if LEVEL.key?( level )
				level = LEVEL[ level ]
			end

			logger = Logger.new( $stderr )
			PluginFactory.logger = logger
			PluginFactory.logger.level = level

			# Only do this when executing from a spec in TextMate
			if ENV['HTML_LOGGING'] || (ENV['TM_FILENAME'] && ENV['TM_FILENAME'] =~ /_spec\.rb/)
				Thread.current['logger-output'] = []
				logdevice = ArrayLogger.new( Thread.current['logger-output'] )
				PluginFactory.logger = Logger.new( logdevice )
				# PluginFactory.logger.level = level
				PluginFactory.logger.formatter = PluginFactory::HtmlLogFormatter.new( logger )
			end
		end

	end # module SpecHelpers

end # module PluginFactory


### Mock with Rspec
Rspec.configure do |c|
	c.mock_with :rspec
	c.include( PluginFactory::SpecHelpers )
end

# vim: set nosta noet ts=4 sw=4:

