[![Build Status](https://travis-ci.org/powerman/perl-FCGI-EV-Std.svg?branch=master)](https://travis-ci.org/powerman/perl-FCGI-EV-Std)
[![Coverage Status](https://coveralls.io/repos/powerman/perl-FCGI-EV-Std/badge.svg?branch=master)](https://coveralls.io/r/powerman/perl-FCGI-EV-Std?branch=master)

# NAME

FCGI::EV::Std - Handler class to use with FCGI::EV

# VERSION

This document describes FCGI::EV::Std version v2.0.1

# SYNOPSIS

    use FCGI::EV::Std;

    # configuration example
    $FCGI::EV::Std::BLOCKING   = 0;
    $FCGI::EV::Std::MAX_STDIN  = 10*1024*1024;
    $FCGI::EV::Std::MAIN       = \&nonblocking_main;
    $FCGI::EV::Std::HUP        = \&hup;

    # for usage example see FCGI::EV module SYNOPSIS

# DESCRIPTION

This module must be used together with FCGI::EV. It will handle CGI
requests received by FCGI::EV. Both blocking and non-blocking CGI request
handling supported.

It will validate size of STDIN: do not accept size larger than configured
in $MAX\_STDIN (1 MB by default), do not accept incomplete STDIN (less
than $ENV{CONTENT\_LENGTH} bytes) - in both cases HTTP reply "417
Expectation Failed" will be returned to browser.

In non-blocking mode it optionally may call user callback function if web
server disconnect before CGI sent it reply (to interrupt processing this
request, if possible).

It compatible with CGI.pm (CGI.pm must be loaded before FCGI::EV::Std
to activate this feature, and you'll need CGI::Stateless module), but may
also work with other modules which parse CGI parameters - in this case
these modules must support work in persistent environment and user
probably has to re-initialize that module state between requests.

# INTERFACE 

There no user-callable methods in this module. Instead, it will call user
functions.

In default configuration it will work in blocking mode and
will call main::main() on each incoming request, with prepared %ENV,
STDIN and STDOUT, so user code may work just as usual CGI application.
Other CGI requests will not be processed until main::main() returns.
Data printed by main::main() to STDOUT will be sent to web server only
after main::main() returns.

It also possible to configure FCGI::EV::Std to work in non-blocking mode.
In this case on each incoming requests it will call main::main($server),
where $server is FCGI::EV object. In this case main::main() shouldn't
do any blocking operations (like using SQL database) but may setup any
events (I/O, timer, etc.) using EV module and should returns quickly.
Other CGI requests will be processed in parallel while this CGI request
wait for events. After CGI will have some data to send, it should use
$server->stdout($data, $is\_eof) method (if $server is still defined - it
may become undef if connection to web server related to this CGI request
was already closed). In addition, FCGI::EV::Std may be configured to call
any user function, say, main::hup($server) if connection to web server will
be closed before CGI sent it reply. WARNING! User shouldn't keep
non-weaken() references to $server in it code!

See also [FCGI::EV::Std::Nonblock](https://metacpan.org/pod/FCGI::EV::Std::Nonblock) - it's helper module which make
writing non-blocking CGI ease.

Use these global variables to configure FCGI::EV::Std:

## BLOCKING

    $FCGI::EV::Std::BLOCKING = 1;

If true, then user function set in $FCGI::EV::Std::MAIN will be called in
blocking mode and without any parameters.

If false, then user function set in $FCGI::EV::Std::MAIN will be called in
non-blocking mode, with parameter $server. Also, if $FCGI::EV::Std::HUP set
to user function, then it will be called if connection to web server is
closed before CGI sent it reply.

## MAX\_STDIN

    $FCGI::EV::Std::MAX_STDIN = 1*1024*1024;

Limit on STDIN size. Increase if you need to receive large files using POST.

## MAIN

    $FCGI::EV::Std::MAIN = \&main::main;

User function called to process (or start processing in non-blocking mode)
incoming CGI request.

## HUP

    $FCGI::EV::Std::HUP = undef;

User function called only in non-blocking mode to
notify about closed connection and, if possible, interrupt current CGI
request.

This function got one parameter - $server object. It's same $server as was
given to $FCGI::EV::Std::MAIN function when this request was started (this
is how user can identify which of currently executing requests was
interrupted). The $server object will be destroyed shortly after that.

# DIAGNOSTICS

- `open STDIN: %s`
- `open STDOUT: %s`

    If anybody will see that, then probably your perl is broken. :)

# SUPPORT

## Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at [https://github.com/powerman/perl-FCGI-EV-Std/issues](https://github.com/powerman/perl-FCGI-EV-Std/issues).
You will be notified automatically of any progress on your issue.

## Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.
Feel free to fork the repository and submit pull requests.

[https://github.com/powerman/perl-FCGI-EV-Std](https://github.com/powerman/perl-FCGI-EV-Std)

    git clone https://github.com/powerman/perl-FCGI-EV-Std.git

## Resources

- MetaCPAN Search

    [https://metacpan.org/search?q=FCGI-EV-Std](https://metacpan.org/search?q=FCGI-EV-Std)

- CPAN Ratings

    [http://cpanratings.perl.org/dist/FCGI-EV-Std](http://cpanratings.perl.org/dist/FCGI-EV-Std)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/FCGI-EV-Std](http://annocpan.org/dist/FCGI-EV-Std)

- CPAN Testers Matrix

    [http://matrix.cpantesters.org/?dist=FCGI-EV-Std](http://matrix.cpantesters.org/?dist=FCGI-EV-Std)

- CPANTS: A CPAN Testing Service (Kwalitee)

    [http://cpants.cpanauthors.org/dist/FCGI-EV-Std](http://cpants.cpanauthors.org/dist/FCGI-EV-Std)

# AUTHOR

Alex Efros <powerman@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2009- by Alex Efros <powerman@cpan.org>.

This is free software, licensed under:

    The MIT (X11) License
