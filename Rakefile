#!/usr/bin/env rake

begin
	require 'hoe'
rescue LoadError
	abort "This Rakefile requires hoe (gem install hoe)"
end

GEMSPEC = 'cztop-reactor.gemspec'


Hoe.plugin :mercurial
Hoe.plugin :signing
Hoe.plugin :deveiate

Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec 'cztop-reactor' do |spec|
	self.readme_file = 'README.md'
	self.history_file = 'History.md'
	self.extra_rdoc_files = FileList[ '*.rdoc', '*.md' ]
	self.urls = {
		home:   'http://deveiate.org/projects/cztop-reactor',
		code:   'http://bitbucket.org/ged/cztop-reactor',
		docs:   'http://deveiate.org/code/cztop-reactor',
		github: 'http://github.com/ged/cztop-reactor',
	}

	spec.license 'ISC'

	spec.developer 'Michael Granger', 'ged@FaerieMUD.org'

	spec.dependency 'loggability', '~> 0.14'
	spec.dependency 'cztop', '~> 0.11'
	spec.dependency 'timers', '~> 4.1'

	spec.dependency 'hoe-deveiate',            '~> 0.9', :developer
	spec.dependency 'simplecov',               '~> 0.13', :developer
	spec.dependency 'rdoc-generator-fivefish', '~> 0.3', :developer

	spec.require_ruby_version( '>=2.2.4' )
	spec.hg_sign_tags = true if spec.respond_to?( :hg_sign_tags= )
	spec.check_history_on_release = true if spec.respond_to?( :check_history_on_release= )

	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end


ENV['VERSION'] ||= hoespec.spec.version.to_s

# Run the tests before checking in
task 'hg:precheckin' => [ :check_history, :check_manifest, :gemspec, :spec ]

task :test => :spec

# Rebuild the ChangeLog immediately before release
file 'ChangeLog'
task :prerelease => 'ChangeLog'
CLOBBER.include( 'ChangeLog' )

desc "Build a coverage report"
task :coverage do
	ENV["COVERAGE"] = 'yes'
	Rake::Task[:spec].invoke
end
CLOBBER.include( 'coverage' )


# Use the fivefish formatter for docs generated from development checkout
if File.directory?( '.hg' )
	require 'rdoc/task'

	Rake::Task[ 'docs' ].clear
	RDoc::Task.new( 'docs' ) do |rdoc|
		rdoc.markup = 'markdown'
		rdoc.main = "README.md"
		rdoc.rdoc_files.include( "*.md", "ChangeLog", "lib/**/*.rb" )

		rdoc.generator = :fivefish
		rdoc.title = 'CZTop-Reactor'
		rdoc.rdoc_dir = 'doc'
	end
end

file 'Manifest.txt'

task :gemspec => GEMSPEC
file GEMSPEC => [ 'Manifest.txt', 'ChangeLog', __FILE__ ]
task GEMSPEC do |task|
	spec = $hoespec.spec
	spec.files.delete( '.gemtest' )
	spec.signing_key = nil
	spec.cert_chain = ['certs/ged.pem']
	spec.version = "#{spec.version.bump}.0.pre#{Time.now.strftime("%Y%m%d%H%M%S")}"
	File.open( task.name, 'w' ) do |fh|
		fh.write( spec.to_ruby )
	end
end
CLOBBER.include( GEMSPEC.to_s )

task :default => :gemspec

