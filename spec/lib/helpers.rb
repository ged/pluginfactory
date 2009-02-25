#!/usr/bin/ruby
# coding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"
	extdir = basedir + "ext"

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
	$LOAD_PATH.unshift( extdir.to_s ) unless $LOAD_PATH.include?( extdir.to_s )
}

require 'erb'

### RSpec helper functions.
module PluginFactory::SpecHelpers

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
			PluginFactory.logger.formatter = HtmlLogFormatter.new( logger )
		end
	end
	
	
end


### Make Logger output stuff in a form that looks nice(er) in SpecMate output.
class HtmlLogFormatter < Logger::Formatter
	include ERB::Util  # for html_escape()

	unless defined?( HTML_LOG_FORMAT )
		HTML_LOG_FORMAT = %q{
		<dd class="log-message %5$s">
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
		</dd>
		}
	end

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
			severity,                                                     # %5$s
			progname,                                                     # %6$s
			html_escape( msg ).gsub(/\n/, '<br />')                       # %7$s
		]

		return self.format % args
	end
	
end


# Override the badly-structured output of the RSpec HTML formatter
require 'spec/runner/formatter/html_formatter'

class Spec::Runner::Formatter::HtmlFormatter
	def example_failed( example, counter, failure )
		failure_style = failure.pending_fixed? ? 'pending_fixed' : 'failed'
		
		unless @header_red
			@output.puts "    <script type=\"text/javascript\">makeRed('rspec-header');</script>"
			@header_red = true
		end
		
		unless @example_group_red
			css_class = 'example_group_%d' % [current_example_group_number || 0]
			@output.puts "    <script type=\"text/javascript\">makeRed('#{css_class}');</script>"
			@example_group_red = true
		end
		
		move_progress()
		
		@output.puts "    <dd class=\"spec #{failure_style}\">",
		             "      <span class=\"failed_spec_name\">#{h(example.description)}</span>",
		             "      <div class=\"failure\" id=\"failure_#{counter}\">"
		if failure.exception
			backtrace = format_backtrace( failure.exception.backtrace )
			message = failure.exception.message
			
			@output.puts "        <div class=\"message\"><code>#{h message}</code></div>",
			             "        <div class=\"backtrace\"><pre>#{backtrace}</pre></div>"
		end

		if extra = extra_failure_content( failure )
			@output.puts( extra )
		end
		
		@output.puts "      </div>",
		             "    </dd>"
		@output.flush
	end


	if instance_methods.include?('global_styles') || instance_methods.include?(:global_styles)
		alias_method :default_global_styles, :global_styles
	else
		def default_global_styles
			"/* No default global_styles (methods: %p)?!? */" % [ instance_methods ]
		end
	end
	
	def global_styles
		css = default_global_styles()
		css << %Q{
			/* Stuff added by #{__FILE__} */

			/* Overrides */
			#rspec-header {
				-webkit-box-shadow: #333 0 2px 5px;
				margin-bottom: 1em;
			}

			.example_group dt {
				-webkit-box-shadow: #333 0 2px 3px;
			}

			/* Style for log output */
			dd.log-message {
				background: #eee;
				padding: 0 2em;
				margin: 0.2em 1em;
				border-bottom: 1px dotted #999;
				border-top: 1px dotted #999;
				text-indent: -1em;
			}

			/* Parts of the message */
			dd.log-message .log-time {
				font-weight: bold;
			}
			dd.log-message .log-time:after {
				content: ": ";
			}
			dd.log-message .log-level {
				font-variant: small-caps;
				border: 1px solid #ccc;
				padding: 1px 2px;
			}
			dd.log-message .log-name {
				font-size: 1.2em;
				color: #1e51b2;
			}
			dd.log-message .log-name:before { content: "«"; }
			dd.log-message .log-name:after { content:  "»"; }

			dd.log-message .log-message-text {
				padding-left: 4px;
				font-family: Monaco, "Andale Mono", "Vera Sans Mono", mono;
			}


			/* Distinguish levels */
			dd.log-message.debug { color: #666; }
			dd.log-message.info {}

			dd.log-message.warn,
			dd.log-message.error {
				background: #ff9;
			}
			dd.log-message.error .log-level,
			dd.log-message.error .log-message-text {
				color: #900;
			}
			dd.log-message.fatal {
				background: #900;
				color: white;
				font-weight: bold;
				border: 0;
			}
			dd.log-message.fatal .log-name {
				color:  white;
			}
		}
		
		return css
	end
end # module PluginFactory::SpecHelpers


# vim: set nosta noet ts=4 sw=4:

