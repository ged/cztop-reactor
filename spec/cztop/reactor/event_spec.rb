#!/usr/bin/env rspec -cfd

require_relative '../../spec_helper'

require 'cztop/reactor/event'


describe CZTop::Reactor::Event do

	DummyPollerEvent = Struct.new( :DummyPollerEvent, :readable?, :writable?, :socket, :events )


	before( :each ) do
		allow( CZTop::Poller::ZMQ::PollerEvent ).to receive( :new ).and_return( poller_event )
	end


	let( :reactor ) { CZTop::Reactor.new }
	let( :poller_event ) do
		DummyPollerEvent.new( false, false, nil, 0 )
	end


	it "looks up the socket via the reactor it was created with" do
		poller_event.socket = 0xDEADBEEF
		event = described_class.new( reactor, 0xFADECAFE )

		expect( reactor ).to receive( :socket_for_ptr ).with( 0xDEADBEEF ).and_return( :the_socket )
		expect( event.socket ).to eq( :the_socket )
	end


	it "knows the poll event(s) that caused it" do
		poller_event.events = CZTop::Poller::ZMQ::POLLIN|CZTop::Poller::ZMQ::POLLERR
		event = described_class.new( reactor, 0xFADECAFE )

		expect( event.poll_events ).to contain_exactly( :read, :err )
	end

end

