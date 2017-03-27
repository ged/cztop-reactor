#!/usr/bin/env rspec -cfd
#encoding: utf-8

require_relative '../spec_helper'

require 'rspec'
require 'cztop/reactor'

describe CZTop::Reactor do

	let( :reactor ) { described_class.new }
	let( :handler_class ) do
		Class.new do
			def handle_io_event(ev); end
			def handle_monitor_event(ev); end
		end
	end
	let( :handler_object ) { handler_class.new }


	describe "socket registration" do

		let( :socket ) { CZTop::Socket::REP.new }


		it "allows a socket to be registered for reads" do
			expect( reactor ).to_not be_registered( socket )
			expect( reactor ).to_not have_event_enabled( socket, :read )
			expect( reactor ).to_not have_event_enabled( socket, :write )

			reactor.register( socket, :read ) {}

			expect( reactor ).to be_registered( socket )
			expect( reactor ).to have_event_enabled( socket, :read )
			expect( reactor ).to_not have_event_enabled( socket, :write )
		end


		it "allows a socket to be registered for reads and writes" do
			expect( reactor ).to_not be_registered( socket )
			expect( reactor ).to_not have_event_enabled( socket, :read )
			expect( reactor ).to_not have_event_enabled( socket, :write )

			reactor.register( socket, :read, :write ) {}

			expect( reactor ).to be_registered( socket )
			expect( reactor ).to have_event_enabled( socket, :read )
			expect( reactor ).to have_event_enabled( socket, :write )
		end


		it "allows a socket to be registered with a handler object instead of a block" do
			expect( reactor ).to_not be_registered( socket )
			expect( reactor ).to_not have_event_enabled( socket, :read )
			expect( reactor ).to_not have_event_enabled( socket, :write )

			reactor.register( socket, :read, :write, handler_object )

			expect( reactor ).to be_registered( socket )
			expect( reactor ).to have_event_enabled( socket, :read )
			expect( reactor ).to have_event_enabled( socket, :write )
		end

		it "errors if no block or handler object is given when registering a socket" do
			expect {
				reactor.register( socket, :read )
			}.to raise_error( LocalJumpError, /no block or handler/i )
		end


		it "allows a registered socket to be unregistered" do
			reactor.register( socket, :read, :write ) {}
			reactor.unregister( socket )

			expect( reactor ).to_not be_registered( socket )
		end


		it "doesn't error when unregistering an unregistered socket" do
			expect {
				reactor.unregister( socket )
			}.to_not raise_error
		end


		it "allows a socket to have one or more events enabled for it after registration" do
			reactor.register( socket ) {}
			expect( reactor ).to_not have_event_enabled( socket, :read )
			expect( reactor ).to_not have_event_enabled( socket, :write )

			reactor.enable_events( socket, :read )
			expect( reactor ).to have_event_enabled( socket, :read )
			expect( reactor ).to_not have_event_enabled( socket, :write )

			reactor.enable_events( socket, :write )
			expect( reactor ).to have_event_enabled( socket, :read )
			expect( reactor ).to have_event_enabled( socket, :write )
		end


		it "allows a socket to have one or more events disabled for it after registration" do
			reactor.register( socket, :read, :write ) {}
			expect( reactor ).to have_event_enabled( socket, :read )
			expect( reactor ).to have_event_enabled( socket, :write )

			reactor.disable_events( socket, :read )
			expect( reactor ).to_not have_event_enabled( socket, :read )
			expect( reactor ).to have_event_enabled( socket, :write )

			reactor.disable_events( socket, :write )
			expect( reactor ).to_not have_event_enabled( socket, :read )
			expect( reactor ).to_not have_event_enabled( socket, :write )
		end


		it "can unregister all of its registered sockets" do
			reactor.register( socket ) {}
			reactor.register( CZTop::Socket::SUB.new ) {}
			reactor.register( CZTop::Socket::REQ.new ) {}

			reactor.clear

			expect( reactor.sockets ).to be_empty
		end

	end


	describe "handler registration" do

		let( :reader ) do
			sock = CZTop::Socket::PAIR.new( '@inproc://callback-test' )
			sock.options.linger = 0
			sock
		end
		let( :writer ) do
			sock = CZTop::Socket::PAIR.new( '>inproc://callback-test' )
			sock.options.linger = 0
			sock
		end

		after( :each ) do
			reader.close
			writer.close
		end


		it "calls a callback when a registered socket becomes readable" do
			callback_called = false
			data = nil

			reactor.register( reader, :read ) do |event|
				expect( event ).to be_a( CZTop::Reactor::Event )
				expect( event ).to be_readable
				expect( event ).to_not be_writable
				expect( event.socket ).to equal( reader )

				event.socket.receive
				callback_called = true
			end

			writer << "stuff"

			reactor.poll_once

			expect( callback_called ).to be_truthy
		end


		it "calls #handle_io_event on a handler object when a socket becomes readable" do
			handler_object = Object.new
			expect( handler_object ).to receive( :handle_io_event ) do |event|
				expect( event ).to be_a( CZTop::Reactor::Event )
				expect( event ).to be_readable
				expect( event ).to_not be_writable
				expect( event.socket ).to equal( reader )
			end

			reactor.register( reader, :read, handler_object )
			writer << "stuff"
			reactor.poll_once
		end

	end


	describe "timer registration" do

		it "allows a callback to be called after a certain amount of time" do
			handle = reactor.add_oneshot_timer( 5 ) {}
			expect( reactor.timers ).to include( handle )
		end


		it "allows a callback to be called periodically on an interval" do
			handle = reactor.add_periodic_timer( 5 ) {}
			expect( reactor.timers ).to include( handle )
		end


		it "allows a timer to be cancelled" do
			handle = reactor.add_periodic_timer( 5 ) {}
			reactor.remove_timer( handle )
			expect( reactor.timers ).to_not include( handle )
		end

	end


	describe "monitors" do

		it "can create and register a monitor for a socket" do
			socket = CZTop::Socket::REP.new
			begin
				monitor = reactor.register_monitor( socket ) {}
				expect( monitor ).to be_a( CZTop::Monitor )
				expect( reactor ).to be_registered( monitor.actor )
			ensure
				monitor.terminate if monitor
			end
		end


		it "can create and register a monitor with a handler object instead of a block" do
			socket = CZTop::Socket::REP.new
			begin
				monitor = reactor.register_monitor( socket, handler_object ) {}
				expect( monitor ).to be_a( CZTop::Monitor )
				expect( reactor ).to be_registered( monitor.actor )
			ensure
				monitor.terminate if monitor
			end
		end


		it "raises an error when registering a monitor with no callback or handler object" do
			socket = CZTop::Socket::REP.new
			expect {
				reactor.register_monitor( socket )
			}.to raise_error( LocalJumpError, /no block or handler/i )
		end

	end


	describe "polling loop" do

		it "processes events until it has no more sockets" do
			reader = CZTop::Socket::PAIR.new( '@inproc://polling-test' )
			writer = CZTop::Socket::PAIR.new( '>inproc://polling-test' )

			data = nil

			reactor.register( writer, :write ) do |ev|
				ev.socket << "stuff"
				reactor.unregister( writer )
			end
			reactor.register( reader, :read ) do |ev|
				msg = ev.socket.receive
				data = msg.frames.first.content
				reactor.stop_polling
			end

			thr = Thread.new do
				Thread.current.abort_on_exception = true
				reactor.start_polling
			end

			thr.join( 2 )
			thr.kill if thr.alive?

			expect( data ).to eq( "stuff" )
		end


		it "doesn't trap interrupts by default" do
			expect( CZTop::Poller::ZMQ ).to receive( :poller_wait ).
				and_raise( Interrupt.new )

			expect {
				reactor.poll_once
			}.to raise_error( Interrupt )
		end


		it "has an option to ignore interrupts if you're doing your own signal-handling'" do
			expect( CZTop::Poller::ZMQ ).to receive( :poller_wait ).
				and_raise( Interrupt.new )

			expect( reactor.poll_once(ignore_interrupts: true) ).to be_nil
		end


		it "ignores EAGAIN/EWOULDBLOCK by default" do
			expect( CZTop::Poller::ZMQ ).to receive( :poller_wait ).
				and_raise( Errno::EWOULDBLOCK.new )

			expect( reactor.poll_once ).to be_nil
		end


		it "has an option to propagate EGAIN/EWOULDBLOCK" do
			expect( CZTop::Poller::ZMQ ).to receive( :poller_wait ).
				and_raise( Errno::EAGAIN.new )

			expect {
				reactor.poll_once( ignore_eagain: false )
			}.to raise_error( Errno::EAGAIN )
		end

	end


end

