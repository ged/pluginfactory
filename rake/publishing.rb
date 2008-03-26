#####################################################################
###	P U B L I C A T I O N   T A S K S
#####################################################################

RELEASE_NOTES_FILE    = 'release.notes'
RELEASE_ANNOUNCE_FILE = 'release.ann'

require 'net/smtp'
require 'net/protocol'
require 'openssl'

### Add SSL to Net::SMTP
class Net::SMTP
	def ssl_start( helo='localhost.localdomain', user=nil, secret=nil, authtype=nil )
		if block_given?
			begin
				do_ssl_start( helo, user, secret, authtype )
				return yield( self )
			ensure
				do_finish
			end
		else
			do_ssl_start( helo, user, secret, authtype )
			return self
		end
	end
	
	
	#######
	private
	#######

	def do_ssl_start( helodomain, user, secret, authtype )
		raise IOError, 'SMTP session already started' if @started
		check_auth_args user, secret, authtype if user or secret

		# Open the connection
      	@debug_output << "opening connection to #{@address}...\n" if @debug_output
		sock = timeout( @open_timeout ) { TCPsocket.new(@address, @port) }

		# Wrap it in the SSL layer
		ssl_context = OpenSSL::SSL::SSLContext.new
		ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
		ssl_sock = OpenSSL::SSL::SSLSocket.new( sock, ssl_context )
		ssl_sock.sync_close = true
		ssl_sock.connect

		# Wrap it in the message-oriented IO layer
		sslmsgio = Net::InternetMessageIO.new( ssl_sock )
		sslmsgio.read_timeout = @read_timeout
		sslmsgio.debug_output = @debug_output

		@socket = sslmsgio

		check_response(critical { recv_response() })
		begin
			if @esmtp
				ehlo helodomain
			else
				helo helodomain
			end
		rescue ProtocolError
			if @esmtp
				@esmtp = false
				@error_occured = false
				retry
			end
			raise
		end
		authenticate user, secret, authtype if user
		@started = true
	ensure
		@socket.close if not @started and @socket and not @socket.closed?
	end
end


begin
	gem 'text-format'

	require 'time'
	require 'rake/tasklib'
	require 'tmail'
	require 'net/smtp'
	require 'etc'
	require 'rubyforge'
	require 'socket'
	require 'text/format'

	### Generate a valid RFC822 message-id
	def gen_message_id
		return "<%s.%s@%s>" % [
			(Time.now.to_f * 10000).to_i.to_s( 36 ),
			(rand( 2 ** 64 - 1 )).to_s( 36 ),
			Socket.gethostname
		]
	end


	namespace :release do
		task :default => [ 'svn:release', :publish, :announce, :project ]

		desc "Generate the release notes"
		task :notes => [RELEASE_NOTES_FILE]
		file RELEASE_NOTES_FILE do |task|
			last_rel_tag = get_latest_release_tag()
			trace "Last release tag is: %p" % [ last_rel_tag ]
			start = get_last_changed_rev( last_rel_tag )
			trace "Starting rev is: %p" % [ start ]
			log_output = make_svn_log( '.', start, 'HEAD' )

			File.open( task.name, File::WRONLY|File::TRUNC|File::CREAT ) do |fh|
				fh.print( log_output )
			end

			edit task.name
		end
		
		
		task :project => [ :rdoc ] do
			when_writing( "Publishing docs to #{PROJECT_SCPURL}" ) do
				run 'ssh', PROJECT_HOST, "rm -rf #{PROJECT_DOCDIR}"
				run 'scp', '-qCr', 'docs', PROJECT_SCPURL
			end
		end

		
		file RELEASE_ANNOUNCE_FILE => [RELEASE_NOTES_FILE] do |task|
			relnotes = File.read( RELEASE_NOTES_FILE )
			announce_body = %{

				Version #{PKG_VERSION} of #{PKG_NAME} has been released.

				#{Text::Format.new(:first_indent => 0).format_one_paragraph(GEMSPEC.description)}

				== Project Page

				  #{GEMSPEC.homepage}

				== Installation

				Via gems:
				
				  $ sudo gem install #{GEMSPEC.name}

				or from source:

				  $ wget http://deveiate.org/code/#{PKG_FILE_NAME}.tar.gz
				  $ tar -xzvf #{PKG_FILE_NAME}.tar.gz
				  $ cd #{PKG_FILE_NAME}
				  $ sudo rake install

				== Changes
				#{relnotes}
			}.gsub( /^\t+/, '' )
			
			File.open( task.name, File::WRONLY|File::TRUNC|File::CREAT ) do |fh|
				fh.print( announce_body )
			end

			edit task.name
		end
		
		
		desc 'Send out a release announcement'
		task :announce => [RELEASE_ANNOUNCE_FILE] do
			email         = TMail::Mail.new
			# email.to      = 'Ruby-Talk List <ruby-talk@ruby-lang.org>'
			email.to      = 'rubymage@gmail.com'
			email.from    = GEMSPEC.email
			email.subject = "[ANN] #{PKG_NAME} #{PKG_VERSION}"
			email.body    = File.read( RELEASE_ANNOUNCE_FILE )
			email.date    = Time.new

			email.message_id = gen_message_id()

			log "About to send the following email:"
			puts '---',
			     email.to_s,
			     '---'
			
				ask_for_confirmation( "Will send via #{SMTP_HOST}." ) do
				pwent = Etc.getpwuid( Process.euid )
				curuser = pwent ? pwent.name : 'unknown'
				username = prompt_with_default( "SMTP user", curuser )
				password = prompt_for_password()
			
				trace "Creating SMTP connection to #{SMTP_HOST}:#{SMTP_PORT}"
				smtp = Net::SMTP.new( SMTP_HOST, SMTP_PORT )
				smtp.set_debug_output( $stdout )
				smtp.esmtp = true

				trace "connecting..."
				smtp.ssl_start( Socket.gethostname, username, password, :plain ) do |smtp|
					trace "sending message..."
					smtp.send_message( email.to_s, email.from, email.to )
				end
				trace "done."
			end
		end
		
	
		desc 'Publish the new release to RubyForge'
		task :publish => [:clobber, :package, :notes] do |task|
			project = GEMSPEC.rubyforge_project

			rf = RubyForge.new
			log 'Logging in to RubyForge'
			rf.login

			config = rf.userconfig
			config['release_notes'] = GEMSPEC.description
			config['release_changes'] = File.read( RELEASE_NOTES_FILE )
			config['preformatted'] = true

			files = FileList[ PKGDIR + GEM_FILE_NAME ]
			files.include PKGDIR + "#{PKG_FILE_NAME}.tar.gz"
			files.include PKGDIR + "#{PKG_FILE_NAME}.tar.bz2"
			files.include PKGDIR + "#{PKG_FILE_NAME}.zip"

			log "Releasing #{PKG_FILE_NAME}"
			when_writing do
				log "Would have run: rf.add_release", project, PKG_NAME.downcase, PKG_VERSION,
				 	*files
			end
		end
	end
	
rescue LoadError => err
	if !Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	
	task :no_release_tasks do
		fail "Release tasks not defined: #{err.message}"
	end
	
	task :release => :no_release_tasks
	task "release:announce" => :no_release_tasks
	task "release:publish" => :no_release_tasks
	task "release:notes" => :no_release_tasks
end

task :release => 'release:default'

