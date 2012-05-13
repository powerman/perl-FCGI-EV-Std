package FCGI::EV::Std::Nonblock;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('1.3.2');    # update POD & Changes & README

# update DEPENDENCIES in POD & Makefile.PL & README
use Scalar::Util qw( weaken refaddr );

use FCGI::EV::Std;
$FCGI::EV::Std::BLOCKING= 0;
$FCGI::EV::Std::MAIN    = \&new;
$FCGI::EV::Std::HUP     = \&HUP;

my $cb_start            = \&main::START;
my $cb_pre              = \&main::PRE;
my $cb_post             = \&main::POST;
my $cb_error            = \&main::ERROR;
#my $HUP                 = undef;

my (%Active, %Server);


sub new {
    my ($server) = @_;
    my $self = bless {}, __PACKAGE__;
    $Active{ refaddr($self)     } = $server;
    $Server{ refaddr($server)   } = $self;
    weaken( $Active{ refaddr($self) } );
    $self->_wrapper($cb_start);
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
#        $HUP && $HUP->($self);
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

sub wrap_cb {
    my ($self, $cb, @p) = @_;
    weaken(my $this = $self);
    return sub { $this && $this->_wrapper($cb, @p, @_) };
}

sub _wrapper {
    my ($this, $cb, @p) = @_;

    $cb_pre->($this);
    my $err = eval { $cb->($this, @p); 1 } ? undef : $@;
    $cb_post->($this);

    if (defined $err) {
        $cb_error->($this, $err);
    }
    return;
}


1; # Magic true value required at end of module
__END__

=head1 NAME

FCGI::EV::Std::Nonblock - Ease non-blocking CGI using FCGI::EV::Std


=head1 VERSION

This document describes FCGI::EV::Std::Nonblock version 1.3.2


=head1 SYNOPSIS

 use FCGI::EV;
 use FCGI::EV::Std;
 use FCGI::EV::Std::Nonblock;   # just loading module will activate it!

 FCGI::EV->new($sock, 'FCGI::EV::Std');

 #
 # Example CGI with FCGI::EV::Std::Nonblock interface
 #
 
 sub PRE {}
 sub POST {}
 sub ERROR {}
 sub START {
    my ($this) = @_;
    $this->{timer} = EV::timer 1, 0, $this->wrap_cb(\&reply);
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

This module will made use of L<FCGI::EV::Std> in non-blocking mode ease for
user. To activate it it's enough to load that module - it will
automatically reconfigure FCGI::EV::Std and that result in calling user
code on incoming CGI requests in completely different way than explained
in L<FCGI::EV::Std> documentation.


=head1 INTERFACE 

This module will configure $BLOCKING, $MAIN and $HUP variables in
FCGI::EV::Std, so only user-configurable variable left is $MAX_STDIN
(see L<FCGI::EV::Std> documentation for details).

On incoming CGI request this module will call user function
main::START($this). The $this parameter is object related to ... this :)
CGI request. This object has several methods listed below, but no fields -
user can use $this as usual HASHREF to store ANY data related to this request.

To keep access to $this when user need to delay processing of this CGI
request until some event happens, user should generate callback for that event
in special way - using $this->wrap_cb($callback, @params) method.
This way when event happens $callback->($this, @params, @event_params)
will be called, and user will have $this.

User should send reply to web server using $this->send($data) and
$this->done() methods.

There also 3 another predefined functions which user must define: main::PRE,
main::POST and main::ERROR. The PRE($this) and POST($this) will be called
before and after user's main::START and $callback prepared using
$this->wrap_cb() - you can use these hooks to setup some environment which
all your callbacks need and make some cleanup after them. The ERROR($this, $@)
will be called if main::START or $callback will throw exception.
Exceptions within PRE, POST and ERROR will not be intercepted and will
kill your process.

=over

=item send( $data )

Will send $data as (part of) CGI reply. Can be called any amount of times
before done() was called.

Return nothing.

=item done()

Will finish processing current request. WARNING! User shouldn't keep
references to $this after calling done()!

Return nothing.

=item wrap_cb( $callback, @params )

Will generate special CODEREF which, when called, will result in calling
$callback->($this, @params, @callback_params). User must ALWAYS use this way
of generating callbacks for event watchers to not lose access to $this
in event handlers, automatically execute main::PRE and main::POST hooks
before and after $callback, and intercept exceptions in $callback (which
will be automatically delivered to main::ERROR hook after executing POST
hook.

The PRE and POST hooks will have only parameter: $this.
The ERROR hook will two parameters: $this and $exception (stored copy of $@).

=back


=head1 DIAGNOSTICS

None.


=head1 CONFIGURATION AND ENVIRONMENT

FCGI::EV::Std::Nonblock requires no configuration files or environment variables.


=head1 DEPENDENCIES

 version


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
