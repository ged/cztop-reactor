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

			def on_connected( fd, endpoint )
				@monitor_events << [ :connected, fd, endpoint ]
			end

		end

		including_class.include( described_class )

		obj = including_class.new
		reactor = CZTop::Reactor.new
		socket = CZTop::Socket::PAIR.new

		obj.with_socket_monitor( reactor, socket, :CONNECTED ) do
			obj.log.debug( "Killing with USR1" )
			Process.kill( :USR1, Process.pid )
			reactor.poll_once
		end

		expect( obj.signals ).to eq([ :USR1 ])
	end


end

