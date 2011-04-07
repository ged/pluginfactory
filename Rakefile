#!/usr/bin/env rake

require 'hoe'

Hoe.plugin :mercurial
Hoe.plugin :signing

Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec 'pluginfactory' do
	self.readme_file = 'README.md'
	self.history_file = 'History.md'

	self.developer 'Martin Chase', 'stillflame@FaerieMUD.org'
	self.developer 'Michael Granger', 'ged@FaerieMUD.org'

	self.extra_dev_deps.push *{
		'rspec' => '~> 2.4',
	}

	self.spec_extras[:licenses] = ["BSD"]

	self.hg_sign_tags = true if self.respond_to?( :hg_sign_tags= )
	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end

ENV['VERSION'] ||= hoespec.spec.version.to_s

