# -*- ruby -*-
#encoding: utf-8

require 'loggability'
require 'timers'
require 'ffi'
require 'monitor'

require 'cztop'
require 'cztop/poller'
require 'cztop/has_ffi_delegate'


# An implementation of the Reactor pattern described in
# [Pattern-Oriented Software Architecture (Volume 2)][POSA2]. It allows
# an asynchronous application to be described as one or more "reactions"
# to events, in this case either I/O conditions on a ZMQ socket or a
# timer expiring.
#
# [POSA2]: http://www.cs.wustl.edu/~schmidt/POSA/POSA2/
#
class CZTop::Reactor
	extend Loggability
	include MonitorMixin

	# The version of this library
	VERSION = '0.6.0'

	# The maximum number of seconds to wait for events when there are no timers
	# registered.
	DEFAULT_POLL_INTERVAL = 0.250

	# The events that can be registered and the corresponding mask
	VALID_EVENTS = {
		 read: CZTop::Poller::ZMQ::POLLIN,
		write: CZTop::Poller::ZMQ::POLLOUT,
	}.freeze


	autoload :Event, 'cztop/reactor/event'


	# Loggability API -- set up a logger for this class
	log_as :cztop


	### Create a new CZTop::Reactor
	def initialize
		@sockets = Hash.new do |hsh,key|
			hsh[ key ] = { events: [], handler: nil }
		end
		@timers = Timers::Group.new
		@wakeup_timer = @timers.every( DEFAULT_POLL_INTERVAL ) do
			# No-op -- just ensures that new timers that are registered are only
			# delayed by (at most) the DEFAULT_POLL_INTERVAL before they start.
		end

		@socket_pointers = {}

		@poller_ptr = CZTop::Poller::ZMQ.poller_new
		ObjectSpace.define_finalizer( @poller_ptr, -> (obj_id) {
			# $stderr.puts "Freeing the poller pointer %p" % [ @poller_ptr ]
			ptr_ptr = ::FFI::MemoryPointer.new( :pointer )
			ptr_ptr.write_pointer( @poller_ptr )
			CZTop::Poller::ZMQ.poller_destroy( ptr_ptr )
		})
		@event_ptr = ::FFI::MemoryPointer.new( CZTop::Poller::ZMQ::PollerEvent )

		super
	end


	######
	public
	######

	##
	# Sockets and the handlers that handle their IO
	attr_reader :sockets

	##
	# Registered timers as a Timers::Group
	attr_reader :timers

	##
	# The handle of the default timer that is used to ensure the polling loop
	# notices new sockets and timers.
	attr_reader :wakeup_timer


	#
	# Sockets
	#

	### Register the specified +socket+ with the reactor for the specified +events+.
	### The following events are supported:
	###
	### [<tt>:read</tt>]
	###   Data may be read from the socket without blocking.
	### [<tt>:write</tt>]
	###   Data may be written to the socket without blocking.
	###
	### Registering a handle will unregister any previously registered
	### event/handler+arguments pairs associated with the handle.
	###
	def register( socket, *events, &handler )
		if !events.empty? && !events.last.is_a?( Symbol )
			handler_obj = events.pop
			handler = handler_obj.method( :handle_io_event )
		end

		raise LocalJumpError, "no block or handler given" unless handler

		self.synchronize do
			self.unregister( socket )

			ptr = self.ptr_for_socket( socket )
			rc = CZTop::Poller::ZMQ.poller_add( @poller_ptr, ptr, nil, 0 )
			self.log.debug "poller_add: rc = %p" % [ rc ]
			CZTop::HasFFIDelegate.raise_zmq_err if rc == -1

			self.log.info "Registered: %p with handler: %p" % [ socket, handler ]
			self.sockets[ socket ][ :handler ] = handler
			self.enable_events( socket, *events )

			@socket_pointers[ ptr.to_i ] = socket
		end
	end
	alias_method :add, :register
	alias_method :register_socket, :register


	### Remove the specified <tt>socket</tt> from the receiver's list of registered
	### handles, if present. Returns the handle if it was registered, or
	### <tt>nil</tt> if it was not.
	def unregister( socket )
		self.synchronize do
			if self.sockets.delete( socket )
				self.log.info "Unregistering: %p" % [ socket ]
				ptr = self.ptr_for_socket( socket )
				rc = CZTop::Poller::ZMQ.poller_remove( @poller_ptr, ptr )
				self.log.debug "poller_remove: rc = %p" % [ rc ]
				CZTop::HasFFIDelegate.raise_zmq_err if rc == -1
			end

			@socket_pointers.delete( ptr.to_i )
		end
	end
	alias_method :remove, :unregister
	alias_method :unregister_socket, :unregister


	### Returns +true+ if the given +socket+ handle is registered with the reactor.
	def registered?( socket )
		return self.sockets.key?( socket )
	end


	### Add the specified +events+ to the list that will be polled for on the
	### given +socket+.
	def enable_events( socket, *events )
		invalid = events - ( events & VALID_EVENTS.keys )
		if !invalid.empty?
			raise ArgumentError, "invalid events: %p" % [ invalid ]
		end

		self.synchronize do
			socket = self.socket_for_ptr( socket ) if socket.is_a?( FFI::Pointer )
			raise ArgumentError, "%p is not registered yet" % [ socket ] unless
				self.registered?( socket )

			self.sockets[ socket ][ :events ] |= events
			self.update_poller_for( socket )
		end
	end
	alias_method :enable_event, :enable_events
	alias_method :enable_socket_events, :enable_events
	alias_method :enable_socket_event, :enable_events


	### Remove the specified +events+ from the list that will be polled for on
	### the given +socket+ handle.
	def disable_events( socket, *events )
		self.synchronize do
			socket = self.socket_for_ptr( socket ) if socket.is_a?( FFI::Pointer )
			self.sockets[ socket ][:events] -= events
			self.update_poller_for( socket )
		end
	end
	alias_method :disable_socket_events, :disable_events


	### Returns +true+ if the specified +event+ is enabled for the given +socket+.
	def event_enabled?( socket, event )
		socket = self.socket_for_ptr( socket ) if socket.is_a?( FFI::Pointer )

		return false unless self.sockets.key?( socket )
		return self.sockets[ socket ][ :events ].include?( event )
	end
	alias_method :has_event_enabled?, :event_enabled?
	alias_method :socket_event_enabled?, :event_enabled?


	### Returns <tt>true</tt> if no sockets are registered.
	def empty?
		return self.sockets.empty? && self.timers.empty?
	end


	### Clear all registered sockets and returns the sockets that were cleared.
	def clear
		self.synchronize do
			sockets = self.sockets.keys
			sockets.each {|sock| self.unregister(sock) }
			return sockets
		end
	end


	#
	# Timers
	#

	### Register a timer that will call the specified +callback+ once after +delay+
	### seconds.
	def add_oneshot_timer( delay, &callback )
		self.log.debug "Registering a oneshot timer: will call %p after %0.2fs" %
			[ callback, delay ]
		return self.timers.after( delay, &callback )
	end


	### Register a timer that will call the specified +callback+ once every
	### +delay+ seconds until it is cancelled.
	def add_periodic_timer( delay, &callback )
		self.log.debug "Registering a periodic timer: will call %p every %0.2fs" %
			[ callback, delay ]
		return self.timers.every( delay, &callback )
	end


	### Remove the specified +timer+ from the reactor.
	def remove_timer( timer )
		timer.cancel
	end


	### Restore the specified +timer+ to the reactor.
	def resume_timer( timer )
		timer.reset
	end


	### Pause all timers registered with the reactor.
	def pause_timers
		self.timers.pause
	end


	### Resume all timers registered with the reactor.
	def resume_timers
		self.timers.resume
	end


	### Execute a +block+ with all registered timers paused, then resume them when
	### the block returns.
	def with_timers_paused
		self.pause_timers
		return yield
	ensure
		self.resume_timers
	end


	#
	# Monitors
	#

	### Create a CZTop::Monitor for the specified +socket+ that will listen for the
	### specified +events+ (which are monitor events, not I/O events). It will be automatically
	### registered with the reactor for the `:read` event with the specified +callback+,
	### then returned.
	def register_monitor( socket, *events, &callback )
		if !events.empty? && !events.last.is_a?( String )
			handler = events.pop
			callback = handler.method( :handle_monitor_event )
		end

		events.push( 'ALL' ) if events.empty?

		monitor = CZTop::Monitor.new( socket )
		monitor.listen( *events )
		monitor.start

		self.register( monitor.actor, :read, &callback )

		return monitor
	end
	alias_method :start_monitor, :register_monitor



	#
	# Polling
	#

	### Poll registered sockets and fire timers until they're all unregistered.
	def start_polling( **opts )
		self.poll_once( **opts ) until self.empty?
	end


	### Poll registered sockets or fire timers and return.
	def poll_once( ignore_interrupts: false, ignore_eagain: true )
		self.log.debug "Polling %d sockets" % [ self.sockets.length ]

		wait_interval = self.timers.wait_interval || DEFAULT_POLL_INTERVAL

		# If there's a timer already due to fire, don't wait at all
		event = if wait_interval > 0
				self.log.debug "Waiting for IO for %fms" % [ wait_interval * 1000 ]
				self.wait( wait_interval * 1000 )
			else
				nil
			end

		self.log.debug "Got event %p" % [ event ]
		if event
			# self.log.debug "Got event: %p" % [ event ]
			handler = self.sockets[ event.socket ][ :handler ]
			handler.call( event )
		else
			self.log.debug "Expired: firing timers."
			self.timers.fire
		end

		self.log.debug "%d sockets after polling: %p" % [ self.sockets.length, self.sockets ]
	rescue Interrupt
		raise unless ignore_interrupts
		self.log.debug "Interrupted."
		return nil
	rescue Errno::EAGAIN, Errno::EWOULDBLOCK
		raise unless ignore_eagain
		self.log.debug "EAGAIN"
		return nil
	end


	### Stop polling for events and prepare to shut down.
	def stop_polling
		self.log.debug "Stopping the poll loop."
		self.clear
		self.timers.cancel
	end


	### Return the socket object for the given +pointer+ (an FFI::Pointer), or +nil+ if the
	### pointer is unknown.
	def socket_for_ptr( pointer )
		return @socket_pointers[ pointer.to_i ]
	end


	#########
	protected
	#########

	### Waits for events on registered sockets. Returns the first such event, or +nil+ if
	### no events arrived within the specified +timeout+. If +timeout+ is -1, wait
	### indefinitely.
	def wait( timeout=-1 )
		rc = CZTop::Poller::ZMQ.poller_wait( @poller_ptr, @event_ptr, timeout )
		if rc == -1
			if CZMQ::FFI::Errors.errno != Errno::ETIMEDOUT::Errno
				CZTop::HasFFIDelegate.raise_zmq_err
			end
			return nil
		end
		return Event.new(self, @event_ptr)
	end


	### Modify the underlying poller's event mask with the events +socket+ is
	### interested in.
	def update_poller_for( socket )
		self.synchronize do
			event_mask = self.mask_for( socket )

			ptr = self.ptr_for_socket( socket )
			rc = CZTop::Poller::ZMQ.poller_modify( @poller_ptr, ptr, event_mask )
			CZTop::HasFFIDelegate.raise_zmq_err if rc == -1
		end
	end


	### Return the ZMQ bitmask for the events the specified +socket+ is registered
	### for.
	def mask_for( socket )
		return self.sockets[ socket ][ :events ].inject( 0 ) do |mask, evt|
			mask | VALID_EVENTS[ evt ]
		end
	end


	### Return the low-level handle for +socket+. Raises an ArgumentError if argument is
	### not a CZTop::Socket or a CZTop::Actor.
	def ptr_for_socket( socket )
		unless socket.is_a?( CZTop::Socket ) || socket.is_a?( CZTop::Actor )
			raise ArgumentError, "expected a CZTop::Socket or a CZTop::Actor, got %p" % [ socket ]
		end
		return CZMQ::FFI::Zsock.resolve( socket )
	end

end # class CZTop::Reactor

