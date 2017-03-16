# -*- encoding: utf-8 -*-
# stub: cztop-reactor 0.1.pre20170316153423 ruby lib

Gem::Specification.new do |s|
  s.name = "cztop-reactor".freeze
  s.version = "0.1.pre20170316153423"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Granger".freeze]
  s.cert_chain = ["certs/ged.pem".freeze]
  s.date = "2017-03-16"
  s.description = "This is an implementation of the Reactor pattern described in [Pattern-Oriented\nSoftware Architecture (Volume 2)][POSA2]. It allows an asynchronous application\nto be described as one or more \"reactions\" to events, in this case either I/O\nconditions on a ZMQ socket or a timer expiring.\n\nA simple example:\n\n\t\t# Start a SERVER socket, and print out any messages sent to it\n    reactor = CZTop::Reactor.new\n\t\tsocket = CZTop::Socket::SERVER.new\n\t\tsocket.bind( 'tcp://0.0.0.0:8' )\n\t\treactor.register( socket, :read ) do |event|\n\t\t\tif event.readable?\n\t\t\t\tmessage = event.socket.receive\n\t\t\t\tputs \"Read: %p\" % [ message.to_a ]\n\t\t\tend\n\t\tend\n\t\treactor.start_polling".freeze
  s.email = ["ged@FaerieMUD.org".freeze]
  s.extra_rdoc_files = ["History.md".freeze, "LICENSE.txt".freeze, "Manifest.txt".freeze, "README.md".freeze, "History.md".freeze, "README.md".freeze]
  s.files = [".document".freeze, ".rdoc_options".freeze, ".simplecov".freeze, "ChangeLog".freeze, "History.md".freeze, "LICENSE.txt".freeze, "Manifest.txt".freeze, "README.md".freeze, "Rakefile".freeze, "lib/cztop/reactor.rb".freeze, "lib/cztop/reactor/event.rb".freeze, "spec/cztop/reactor/event_spec.rb".freeze, "spec/cztop/reactor_spec.rb".freeze, "spec/spec_helper.rb".freeze]
  s.homepage = "http://deveiate.org/projects/cztop-reactor".freeze
  s.licenses = ["ISC".freeze]
  s.rdoc_options = ["--main".freeze, "README.md".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.2.4".freeze)
  s.rubygems_version = "2.6.8".freeze
  s.summary = "This is an implementation of the Reactor pattern described in [Pattern-Oriented Software Architecture (Volume 2)][POSA2]".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<loggability>.freeze, ["~> 0.14"])
      s.add_runtime_dependency(%q<cztop>.freeze, ["~> 0.11"])
      s.add_development_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
      s.add_development_dependency(%q<hoe-deveiate>.freeze, ["~> 0.8"])
      s.add_development_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
      s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.13"])
      s.add_development_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.3"])
      s.add_development_dependency(%q<rdoc>.freeze, ["~> 4.0"])
      s.add_development_dependency(%q<hoe>.freeze, ["~> 3.15"])
    else
      s.add_dependency(%q<loggability>.freeze, ["~> 0.14"])
      s.add_dependency(%q<cztop>.freeze, ["~> 0.11"])
      s.add_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
      s.add_dependency(%q<hoe-deveiate>.freeze, ["~> 0.8"])
      s.add_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
      s.add_dependency(%q<simplecov>.freeze, ["~> 0.13"])
      s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.3"])
      s.add_dependency(%q<rdoc>.freeze, ["~> 4.0"])
      s.add_dependency(%q<hoe>.freeze, ["~> 3.15"])
    end
  else
    s.add_dependency(%q<loggability>.freeze, ["~> 0.14"])
    s.add_dependency(%q<cztop>.freeze, ["~> 0.11"])
    s.add_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
    s.add_dependency(%q<hoe-deveiate>.freeze, ["~> 0.8"])
    s.add_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
    s.add_dependency(%q<simplecov>.freeze, ["~> 0.13"])
    s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.3"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 4.0"])
    s.add_dependency(%q<hoe>.freeze, ["~> 3.15"])
  end
end
