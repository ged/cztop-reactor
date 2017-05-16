# -*- ruby -*-
#encoding: utf-8

require 'loggability'
require 'securerandom'
require 'cztop/reactor' unless defined?( CZTop::Reactor )


# A mixin that adds methods for running a process with queued signal handling
# via a ZMQ PAIR socket.
#
#     require 'cztop'
#     require 'cztop/reactor'
#     require 'cztop/reactor/signal_handling'
#
#     class MyDaemon
#         include 'cztop/reactor/signal_handling'
#
#         def start
#             @reactor = CZTop::Reactor.new
#             @reactor.register( @socket, :read, &self.method(:handle_io_event) )
#             self.with_signal_handler( @reactor, :HUP, :INT, :TERM ) do
#                 @reactor.start_polling( ignore_interrupts: true )
#             end
#         end
#
#         def stop
#             @reactor.stop_polling
#         end
#
#         def handle_signal( signal_name )
#             case signal_name
#             when :INT, :TERM, :HUP
#                 self.stop
#             else
#                 super
#             end
#         end
#     end
#
# With this mixin included, you can wrap a block with a call to
# #with_signal_handler, and when a signal arrives, the #handle_signal method
# will be called with the name of the signal.
module CZTop::Reactor::SignalHandling


	# The name of the thread-local variable that stores pending signals.
	SIGNAL_QUEUE_KEY = :signal_queue


	### Inclusion callback -- add Loggability to including classes.
	def self::included( mod )
		super
		mod.extend( Loggability )
		mod.log_to( :cztop ) unless Loggability.log_host?( mod )
	end


	### Wrap a block in signal-handling.
	def with_signal_handler( reactor, *signals )
		self.set_up_signal_handling( reactor )
		self.set_signal_traps( *signals )

		return yield

	ensure
		self.reset_signal_traps( *signals )
		self.clean_up_signal_handling( reactor )
	end


	### Simulate the receipt of the specified +signal+ (probably only useful
	### in testing).
	def simulate_signal( signal )
		Thread.main[ SIGNAL_QUEUE_KEY ] << signal.to_sym
		self.wake_up
	end


	#########
	protected
	#########

	### Set up data structures for signal handling.
	def set_up_signal_handling( reactor )
		Thread.main[ SIGNAL_QUEUE_KEY ] = []

		endpoint = "inproc://signal-handler-%s" % [ SecureRandom.hex(8) ]
		@self_pipe = {
			reader: CZTop::Socket::PAIR.new( "@#{endpoint}" ),
			writer: CZTop::Socket::PAIR.new( ">#{endpoint}" )
		}

		# :TODO: Consider calling #set_unbounded on the PAIR sockets

		reactor.register( @self_pipe[:reader], :read, &self.method(:handle_queued_signals) )
	end


	### Tear down the data structures for signal handling
	def clean_up_signal_handling( reactor )
		reactor.unregister( @self_pipe[:reader] )

		@self_pipe[:writer].options.linger = 0
		@self_pipe[:writer].close
		@self_pipe[:reader].options.linger = 0
		@self_pipe[:reader].close

		Thread.main[ SIGNAL_QUEUE_KEY ].clear
	end


	### Look for any signals that arrived and handle them.
	def handle_queued_signals( _event )
		while sig = Thread.main[ SIGNAL_QUEUE_KEY ].shift
			self.log.debug "  got a queued signal: %p" % [ sig ]
			self.handle_signal( sig )
		end
	end


	### Default signal-handler callback -- this raises an exception by default.
	def handle_signal( signal_name )
		raise NotImplementedError, "unhandled signal %s" % [ signal_name ]
	end


	### Signal through the self-pipe that one or more signals has been queued.
	def wake_up
		@self_pipe[:writer].signal( 1 )
	end


	### Set up signal traps for the specified +signals+.
	def set_signal_traps( *signals )
		self.log.debug "Setting up deferred signal handlers."
		signals.each do |sig|
			Signal.trap( sig ) do
				Thread.main[ SIGNAL_QUEUE_KEY ] << sig
				self.wake_up
			end
		end
	end


	### Set the traps for the specified +signals+ to IGNORE.
	def ignore_signals( *signals )
		self.log.debug "Ignoring signals."
		signals.each do |sig|
			next if sig == :CHLD
			Signal.trap( sig, :IGNORE )
		end
	end


	### Set the traps for the specified +signals+ to the default handler.
	def reset_signal_traps( *signals )
		self.log.debug "Restoring default signal handlers."
		signals.each do |sig|
			Signal.trap( sig, :DEFAULT )
		end
	end

end # module CZTop::Reactor::SignalHandling
