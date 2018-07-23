#!/usr/bin/env rspec -cfd

require_relative '../../spec_helper'

require 'cztop/reactor/socket_monitoring'


describe CZTop::Reactor::SocketMonitoring do

	it "can add a socket monitor setup to a reactor for a block" do
		including_class = Class.new do

			def initialize
				@monitor_events = []
			end

			attr_reader :monitor_events

			def on_connect_delayed( fd, endpoint )
				@monitor_events << :connect_delayed
			end

		end

		including_class.include( described_class )

		obj = including_class.new
		reactor = CZTop::Reactor.new
		listener = CZTop::Socket::SERVER.new( '@tcp://127.0.0.1:*' )
		socket = CZTop::Socket::CLIENT.new

		obj.with_socket_monitor( reactor, socket, :CONNECTED ) do
			socket.connect( listener.last_endpoint )
			reactor.poll_once
		end

		expect( obj.monitor_events ).to include( :connect_delayed )
	end


end

