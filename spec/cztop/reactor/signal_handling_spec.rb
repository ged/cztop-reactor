#!/usr/bin/env rspec -cfd

require_relative '../../spec_helper'

require 'cztop/reactor/signal_handling'


describe CZTop::Reactor::SignalHandling do

	it "can add a signal handler setup to a reactor for a block" do
		including_class = Class.new do

			def initialize
				@signals = []
			end

			attr_reader :signals

			def handle_signal( signal_name )
				self.signals << signal_name
			end

		end

		including_class.include( described_class )

		obj = including_class.new
		reactor = CZTop::Reactor.new

		obj.with_signal_handler( reactor, :USR1 ) do
			obj.log.debug( "Killing with USR1" )
			Process.kill( :USR1, Process.pid )
			reactor.poll_once
		end

		expect( obj.signals ).to eq([ :USR1 ])
	end


	it "raises if the including class doesn't provide a #handle_signal method" do
		including_class = Class.new
		including_class.include( described_class )

		obj = including_class.new
		reactor = CZTop::Reactor.new

		expect {
			obj.with_signal_handler( reactor, :USR1 ) do
				obj.log.debug( "Killing with USR1" )
				Process.kill( :USR1, Process.pid )
				reactor.poll_once
			end
		}.to raise_error( NotImplementedError, /unhandled signal USR1/i )
	end

end

