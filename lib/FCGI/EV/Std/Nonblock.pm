package FCGI::EV::Std::Nonblock;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.0.2');    # update POD & Changes & README

# update DEPENDENCIES in POD & Makefile.PL & README
use Scalar::Util qw( weaken refaddr );

use FCGI::EV::Std;
$FCGI::EV::Std::BLOCKING= 0;
$FCGI::EV::Std::MAIN    = \&new;
$FCGI::EV::Std::HUP     = \&HUP;

my $HANDLER             = \&main::HANDLER;
my $HUP                 = \&main::HUP;

my (%Active, %Server);


sub new {
    my ($server) = @_;
    my $self = bless {}, __PACKAGE__;
    $Active{ refaddr($self)     } = $server;
    $Server{ refaddr($server)   } = $self;
    weaken( $Active{ refaddr($self) } );
    $HANDLER->($self);
    return;
}

sub done {
    my ($self) = @_;
    if (exists $Active{ refaddr($self) }) {
        my $server = delete $Active{ refaddr($self) };
        if ($server) {
            delete $Server{ refaddr($server) };
            $server->stdout(q{}, 1);
        }
    }
    else {
        croak 'this request already done()';
    }
    return;
}

sub HUP {
    my ($server) = @_;
    return if !$server; # may happens during global destruction
    if (exists $Server{ refaddr($server) }) {
        my $self = delete $Server{ refaddr($server) };
        $HUP->($self);
    }
    return;
}

sub send {  ## no critic (ProhibitBuiltinHomonyms)
    my ($self, $buf) = @_;
    my $server = $Active{ refaddr($self) };
    if ($server) {
        $server->stdout($buf, 0);
    }
    return;
}

sub make_cb {
    my ($self, @p) = @_;
    weaken( my $this = $self );
    return sub { $this && $HANDLER->($this, @p, @_) };
}


1; # Magic true value required at end of module
__END__

=head1 NAME

FCGI::EV::Std::Nonblock - Ease non-blocking CGI using FCGI::EV::Std


=head1 VERSION

This document describes FCGI::EV::Std::Nonblock version 0.0.2


=head1 SYNOPSIS

 use FCGI::EV;
 use FCGI::EV::Std;
 use FCGI::EV::Std::Nonblock;   # just loading module will activate it!

 FCGI::EV->new($sock, 'FCGI::EV::Std');

 #
 # Example CGI with FCGI::EV::Std::Nonblock interface
 #
 
 sub HUP {}

 sub HANDLER {
    my ($this, $callback, @params) = @_;
    if (!defined $callback) {
        # new request!
        EV::timer 1, 0, $this->make_cb(\&reply);
    }
    else {
        # continue request ...
        $callback->($this, @params);
    }
 }

 sub reply {
    my ($this) = @_;
    $this->send("Status: 200 OK\r\n");
    $this->send("Content-Type: text/plain\r\n\r\n");
    $this->send("Reply after 1 sec!");
    $this->done();
    return;
 }


=head1 DESCRIPTION

This module will made using L<FCGI::EV::Std> in non-blocking mode ease for
user. To activate it it's enough to load that module - it will
automatically reconfigure FCGI::EV::Std and that result in calling user
code on incoming CGI requests in completely different way than explained
in L<FCGI::EV::Std> documentation.


=head1 INTERFACE 

This module will configure $BLOCKING, $MAIN and $HUP variables in
FCGI::EV::Std, so only user-configurable variable left is $MAX_STDIN
(see L<FCGI::EV::Std> documentation for details).

On incoming CGI request this module will call user function
main::HANDLER($this). The $this parameter is object related to ... this :)
CGI request. This object has several methods listed below, but no fields -
user can use $this as usual HASHREF to store ANY data related to this request.

To keep access to $this in when user need to delay processing of this CGI
request until some event happens, user should generate callback for that event
in special way - using $this->make_cb($callback, @params) method.
This way when event happens main::HANDLER($this, $callback, @params) will be
called, and user will have both $this and $callback to run.

As you see, main::HANDLER() will be called both when new CGI request start,
and when it continues after some event. User can distinguish between these
cases by checking amount of arguments - when new request start there will be
only argument ($this).

User should send reply to web server using $this->send($data) and
$this->done() methods.

If connection to web server become broken this module will call user function
main::HUP($this). Of course, $this will be same object as was sent to
main::HANDLER() when this CGI request was started. So user have to provide
at least empty sub HUP {} if he doesn't wanna receive such notifications.

=over

=item send( $data )

Will send $data as (part of) CGI reply. Can be called any amount of times
before done() was called.

Return nothing.

=item done()

Will finish processing current request. WARNING! User shouldn't keep
references to $this after calling done()!

Return nothing.

=item make_cb( $callback, @params )

Will generate special CODEREF which, when called, will result in calling
main::HANDLER($this, $callback, @params). User must ALWAYS use this way
of generating callbacks for event watchers to not lose access to $this
and have same entry point for all events (main::HANDLER()).

=back


=head1 DIAGNOSTICS

None.


=head1 CONFIGURATION AND ENVIRONMENT

FCGI::EV::Std::Nonblock requires no configuration files or environment variables.


=head1 DEPENDENCIES

None.


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-fcgi-ev-std-nonblock@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Alex Efros  C<< <powerman-asdf@ya.ru> >>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Alex Efros C<< <powerman-asdf@ya.ru> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
