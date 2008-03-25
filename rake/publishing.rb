#####################################################################
###	P U B L I C A T I O N   T A S K S
#####################################################################

RELEASE_NOTES_FILE    = 'release.notes'
RELEASE_ANNOUNCE_FILE = 'release.ann'


begin
	gem 'tlsmail'
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
		task :default => [ :gem, :source, :announcement ]
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
			email.to      = 'ged@FaerieMUD.org'
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
			
				smtp = Net::SMTP.new( SMTP_HOST, SMTP_PORT )
				smtp.set_debug_output( $stderr )
				smtp.enable_tls( OpenSSL::SSL::VERIFY_NONE )
				smtp.esmtp = true

				smtp.start( username, password, :plain ) do |smtp|
					smtp.send_message( email.to_s, email.from, email.to )
				end
			end
		end
		
	
		desc 'Package and upload to RubyForge'
		task :gem => [:clobber, :package, :notes] do |task|
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
				trace "rf.add_release", project, PKG_NAME.downcase, PKG_VERSION, *files
			end
		end
	end
	
rescue LoadError, Gem::Error => err
	if !Object.const_set?( :Gem )
		require 'rubygems'
		retry
	end
	
	task :no_release_tasks do
		fail "Release tasks not defined: #{err.message}"
	end
	
	task :release => :no_release_tasks
end

task :release => 'release:default'

