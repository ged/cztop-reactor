# -*- ruby -*-
#encoding: utf-8

require 'cztop'
require 'cztop/poller'
require 'cztop/reactor' unless defined?( CZTop::Reactor )



# Represents an event returned by {CZTop::Poller#wait}.
class CZTop::Reactor::Event

	# Poll events in bitwise order
	POLL_EVENTS = [
		:read,
		:write,
		:err
	]


	### Create a new event from the specified +reactor+ and +event_ptr+.
	def initialize( reactor, event_ptr )
		@reactor = reactor
		@poller_event = CZTop::Poller::ZMQ::PollerEvent.new( event_ptr )
	end


	##
	# The CZTop::Reactor that generated this event
	attr_reader :reactor


	### Get the Socket or Actor the event corresponds to.
	def socket
		return @socket ||= self.reactor.socket_for_ptr( @poller_event[:socket] )
	end


	### Returns +true+ if the event indicates the socket is readable.
	def readable?
		return @poller_event.readable?
	end


	### Returns +true+ if the event indicates the socket is writable.
	def writable?
		return @poller_event.writable?
	end


	### Return the poll events this event represents.
	def poll_events
		return POLL_EVENTS.select.with_index {|ev,i| @poller_event[:events][i].nonzero? }
	end


	### Return a human-readable string representation of the event suitable for
	### debugging.
	def inspect
		return "#<%p:%#016x %p {%s}>" % [
			self.class,
			self.object_id * 2,
			self.socket,
			self.poll_events.map( &:to_s ).join( '/' )
		]
	end

end # class CZTop::Reactor::Event
