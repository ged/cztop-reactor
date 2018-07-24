# -*- ruby -*-
# frozen_string_literal: true

require 'cztop/reactor' unless defined?( CZTop::Reactor )

# Methods for logging monitor events.
module CZTop::Reactor::SocketMonitoring

	### Inclusion callback -- add Loggability to including classes.
	def self::included( mod )
		super
		mod.extend( Loggability )
		mod.log_to( :cztop ) unless Loggability.log_host?( mod )
	end


	### Set up a monitor instance variable on object creation.
	def initialize( * ) # :notnew:
		@monitor = nil
	end

	##
	# The CZTop::Monitor for the server socket
	attr_reader :monitor


	### Run the block with monitoring for the specified +socket+.
	def with_socket_monitor( reactor, socket, *events )
		mon = self.set_up_socket_monitor( reactor, socket )

		return yield
	ensure
		self.clean_up_socket_monitor( mon )
	end


	### Create a monitor for the specified +socket+.
	def set_up_socket_monitor( reactor, socket, *events )
		return reactor.register_monitor( socket, *events, &self.method(:on_monitor_event) )
	end


	### Tear down the monitor.
	def clean_up_socket_monitor( mon )
		mon.terminate if mon
	end


	### Handle monitor events.
	def on_monitor_event( monitor_event )
		# self.log.debug "Got monitor event: %p" % [ monitor_event ]

		msg = monitor_event.socket.receive
		type, *payload = *msg
		callback_name = "on_#{type.downcase}"

		if self.respond_to?( callback_name, true )
			self.send( callback_name, *payload )
		else
			self.log.warn "No handler (#%s) for monitored %s event." % [ callback_name, type ]
		end
	end
	alias_method :handle_monitor_event, :on_monitor_event


	#########
	protected
	#########

	### Monitor event callback for socket connection events
	def on_connected( fd, endpoint )
		self.log.debug "Client socket on FD %d connected" % [ fd ]
	end


	### Monitor event callback for socket connection-delayed events
	def on_connect_delayed( fd, endpoint )
		self.log.debug "Client socket on FD %d connection delayed" % [ fd ]
	end


	### Monitor event callback for socket retry events
	def on_connect_retried( fd, endpoint )
		self.log.debug "Retrying connection for socket on FD %d" % [ fd ]
	end


	### Monitor event callback for socket accepted events
	def on_accepted( fd, endpoint )
		self.log.debug "Client socket on FD %d accepted" % [ fd ]
	end


	### Monitor event callback for successful auth events.
	def on_handshake_succeeded( fd, endpoint )
		self.log.debug "Client socket on FD %d handshake succeeded" % [ fd ]
	end


	### Monitor event callback for failed auth events.
	def on_handshake_failed( fd, endpoint )
		self.log.debug "Client socket on FD %d handshake failed" % [ fd ]
	end


	### Monitor event callback for failed handshake events.
	def on_handshake_failed_no_detail( fd, endpoint )
		self.log.debug "Client socket on FD %d handshake failed; no further details are known" % [ fd ]
	end


	### Monitor event callback for failed handshake events.
	def on_handshake_failed_protocol( fd, endpoint )
		self.log.debug "Client socket on FD %d handshake failed: protocol error" % [ fd ]
	end


	### Monitor event callback for socket closed events
	def on_closed( fd, endpoint )
		self.log.debug "Client socket on FD %d closed" % [ fd ]
	end


	### Monitor event callback for socket disconnection events
	def on_disconnected( fd, endpoint )
		self.log.debug "Client socket on FD %d disconnected" % [ fd ]
	end

end # module CZTop::Reactor::SocketMonitoring
