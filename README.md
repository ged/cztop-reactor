# CZTop-Reactor

home
: http://deveiate.org/projects/CZTop-Reactor

code
: http://bitbucket.org/ged/CZTop-Reactor

github
: https://github.com/ged/cztop-reactor

docs
: http://deveiate.org/code/cztop-reactor


## Description

This is an implementation of the Reactor pattern described in [Pattern-Oriented
Software Architecture (Volume 2)][POSA2]. It allows an asynchronous application
to be described as one or more "reactions" to events, in this case either I/O
conditions on a ZMQ socket or a timer expiring.

A simple example:

    # Start a SERVER socket, and print out any messages sent to it
    reactor = CZTop::Reactor.new
    socket = CZTop::Socket::SERVER.new
    socket.bind( 'tcp://0.0.0.0:8' )
    reactor.register( socket, :read ) do |event|
      if event.readable?
        message = event.socket.receive
        puts "Read: %p" % [ message.to_a ]
      end
    end
    reactor.start_polling


## Prerequisites

It should run under any Ruby interpreter that CZTop will, which at the time of
this writing includes:

* MRI (2.3, 2.2)
* Rubinius (HEAD)
* JRuby 9000 (HEAD)

I am also using it (and CZTop) under MRI 2.4.


## Installation

    $ gem install cztop-reactor


## Reasons

I considered submitting this as a patch to `cztop`, but in the end elected to
distribute it as a gem for two reasons:

1. It depends on the `timers` gem, and I didn't want to add this dependency to
   `cztop`. If the [`ztimerset`][ztimerset] spec ever comes out of draft status
   and `cztop` adds an implementation of it, this wouldn't be necessary.
2. I'm not confident enough in my FFI knowledge to know if this is an
   appropriate way to implement this class. I've written numerous C extensions 
   for Ruby, but FFI is still a bit of a mystery to me, and likely will remain 
   so for the foreseeable future given my misgivings about using it.


## Contributing

You can check out the current development source with Mercurial via its
{project page}[http://bitbucket.org/ged/cztop-reactor]. Or if you prefer Git,
via {its Github mirror}[https://github.com/ged/cztop-reactor].

After checking out the source, run:

    $ rake newb

This task will install any missing dependencies, run the tests/specs,
and generate the API documentation.


## License

This library includes source from the CZTop gem by Patrik Wenger, which is
distributed under the terms of the [ISC
License](http://opensource.org/licenses/ISC):

> Copyright (c) 2016, Patrik Wenger
>
> Permission to use, copy, modify, and/or distribute this software for
> any purpose with or without fee is hereby granted, provided that
> the above copyright notice and this permission notice appear in all
> copies.
>
> THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
> WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
> WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
> AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
> DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA
> OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
> TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
> PERFORMANCE OF THIS SOFTWARE.

Everything else is distributed under the same license but is:

Copyright (c) 2017, Michael Granger


[POSA2]: http://www.cs.wustl.edu/~schmidt/POSA/POSA2/
[ztimerset]: http://czmq.zeromq.org/czmq4-0:ztimerset


