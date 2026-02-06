package InteraxiomApi;

use strict;
use warnings;

use constant VERSION => '1.2';

use InteraxiomApi::Answer;

use Carp qw{ carp croak };
use List::Util 'first';
use LWP::UserAgent ();
use JSON ();
use Digest::SHA 'sha1_hex';


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Class constants

use constant {
    API_INTERNAL => 'https://api.interaxiom.local/internal',
    API_PRIVATE => 'https://api.interaxiom.com.au/private',
    API_MYACCOUNT => 'https://api.interaxiom.com.au/myaccount',
};

# End - Class constants
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Class variables

my $UserAgent = LWP::UserAgent->new(timeout => 10);
my $Json = JSON->new->allow_nonref;

my @accessRuleMethods = qw{ GET POST PUT DELETE };
my %configKey = (
    'api-internal' => API_INTERNAL,
    'api-private' => API_PRIVATE,
    'api-myaccount' => API_MYACCOUNT,
);

my %reverseConfigKey = reverse %configKey;

my %configKeySnakeToCamel = (
    'applicationKey'    => 'application_key',
    'publicKey'			=> 'public_key',
    'privateKey'		=> 'private_key',
);

# End - Class variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Class methods

sub new {
    my @keys = qw{ applicationKey publicKey privateKey timeout };

    my ($class, %params) = @_;

    my $configuration = retrieveConfiguration();

    if ($params{'type'}) {
        if (not exists $reverseConfigKey{$params{'type'}}) {
            carp 'Invalid type parameter: defaulting to API_MYACCOUNT';
            $params{'type'} = API_MYACCOUNT;
        }
    }

    if ($configuration) {
        my $endpoint;
        if ($params{'type'}) {
            $endpoint = $reverseConfigKey{$params{'type'}};
        }
        elsif(exists $configuration->{default} and exists $configuration->{default}->{endpoint}) {
            $endpoint = $configuration->{default}->{endpoint};
        }
        if (not $endpoint) {
            carp 'Missing default endpoint in interaxiom-api.conf: defaulting to api-myaccount';
            $endpoint = 'api-myaccount';
        }
        if (not exists $configKey{$endpoint}) {
            local $" = ', ';
            my @legalEndpoints = keys %configKey;
            croak "Invalid endpoint value: $endpoint, valid values are @legalEndpoints";
        }

        $params{'type'} = $configKey{$endpoint};
        if ($configuration->{$endpoint}) {
            foreach my $key (qw( applicationKey publicKey privateKey )) {
                if (not $params{$key} and $configuration->{$endpoint}->{$configKeySnakeToCamel{$key}}) {
                    $params{$key} = $configuration->{$endpoint}->{$configKeySnakeToCamel{$key}};
                }
            }
        }
    }

    if (my @missingParameters = grep { not $params{$_} } qw{ applicationKey publicKey privateKey }) {
        local $" = ', ';
        croak "Missing parameter: @missingParameters";
    }

    my $self = {
        _type   => $params{'type'},
    };

    @$self{@keys} = @params{@keys};

    if ($params{'timeout'}) {
        $class->setRequestTimeout(timeout => $params{'timeout'});
    }

    bless $self, $class;
}

sub setRequestTimeout {
    my ($class, %params) = @_;

    if ($params{'timeout'} =~ /^[0-9]+\z/) {
        $UserAgent->timeout($params{'timeout'});
    }
    elsif (exists $params{'timeout'}) {
        carp "Invalid timeout: $params{'timeout'}";
    }
    else {
        carp 'Missing parameter: timeout';
    }
}

sub retrieveConfiguration {
    my $fh;
    foreach my $filepath ("$ENV{PWD}/interaxiom-api.conf", "$ENV{HOME}/.interaxiom-api.conf", '/etc/interaxiom-api.conf') {
        open($fh, '<', $filepath) and last;
        undef $fh;
    }
    $fh or return undef;

    my (%hash, $section, $key, $value);
    while (<$fh>) {
        chomp;
        if (/^\s*\[([\w-]+)\].*/) {
            $section = $1;
            next;
        }
        if (/^\s*([\w_]+)=([\w_-]+)\s*(;.*)?$/) {
            $key = $1;
            $value = $2;
            $hash{$section}{$key} = $value;
        }
    }
    close($fh);
    return \%hash;
}

# End - Class methods
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Instance methods

sub rawCall {
    my ($self, %params) = @_;

    if (not $params{'path'}) {
        carp "Missing parameter: path";
        return InteraxiomApi::Answer::->new(response => HTTP::Response->new( 500, "Missing parameter: path", [], '{"message":"Missing parameter: path"}'));
    }
    if (not $params{'method'}) {
        carp "Missing parameter: method";
        return InteraxiomApi::Answer::->new(response => HTTP::Response->new( 500, "Missing parameter: method", [], '{"message":"Missing parameter: method"}'));
    }
    my $method = lc $params{'method'};
    my $url = _getTarget($self->{'_type'}, $params{'path'});

    my %httpHeaders;

    my $body = '';
    my %content;

    if (defined $params{'body'} and $method ne 'get' and $method ne 'delete') {
        $body = $Json->encode($params{'body'});

        $httpHeaders{'Content-type'} = 'application/json';
        $content{'Content'} = $body;
    }

    unless ($params{'noSignature'}) {
        my $now = $self->_timeDelta + time;

        if (not $self->{'privateKey'}) {
            carp "Performed an authentified call without providing a valid privateKey";
            return InteraxiomApi::Answer::->new(response => HTTP::Response->new( 500, "Performed an authentified call without providing a valid privateKey", [], '{"message":"Performed an authentified call without providing a valid consumerKey"}'));
        }

        $httpHeaders{'X-Interaxiom-Timestamp'} = $now,
        $httpHeaders{'X-Interaxiom-Public-Key'} = $self->{'publicKey'},
        $httpHeaders{'X-Interaxiom-Private-Key'} = $self->{'privateKey'},
        $httpHeaders{'X-Interaxiom-Signature'} = '$1$' . sha1_hex(join('+', (
            # Full signature is '$1$' followed by the hex digest of the SHA1 of all these data joined by a + sign
            $self->{'publicKey'},			# Application secret
            $self->{'privateKey'},			# Consumer key
            uc $method,                     # HTTP method (uppercased)
            $url,                           # Full URL
            $body,                          # Full body
            $now,                           # Curent Interaxiom server time
        )));
    }

    $httpHeaders{'X-Interaxiom-Application-Key'} = $self->{'applicationKey'};

    return InteraxiomApi::Answer::->new(response => $UserAgent->$method($url, %httpHeaders, %content));
}

# Generation of helper subs: simple wrappers to rawCall
# Generate: get(), post(), put(), delete()
{
    no strict 'refs';

    for my $method (qw{ get post put delete })
    {
        *$method = sub { rawCall(@_, 'method', $method ) };
    }
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Private part

sub _timeDelta {
    my ($self, %params) = @_;

    unless (defined $self->{'_timeDelta'}) {
        if (my $ServerTimeResponse = $self->get(path => 'latest/auth/time', noSignature => 1)) {
            $self->{'_timeDelta'} = ($ServerTimeResponse->content - time);
        }
        else {
            return 0;
        }
    }

    return $self->{'_timeDelta'};
}

sub _getTarget {
    my ($endpoint, $path) = @_;

    $path = "/$path" if $path !~ m#^/#;
    $endpoint =~ s#/1\.0\z## if $path =~ m#^/v[12]#;

    return $endpoint . $path;
}

# End - Instance methods
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

1;

__END__

=head1 NAME

InteraxiomApi - Official Interaxiom Perl wrapper upon the Interaxiom RESTful API.

=head1 SYNOPSIS

  use InteraxiomApi;

  my $Api    = InteraxiomApi->new(type => InteraxiomApi::API_MYACCOUNT, applicationKey => $AK, applicationSecret => $AS, consumerKey => $CK);
  my $Answer = $Api->get(path => '/me');

=head1 DESCRIPTION

This module is an official Perl wrapper that Interaxiom provides in order to offer a simple way to use its RESTful API.
C<InteraxiomApi> handles the authentication layer, and uses C<LWP::UserAgent> in order to run requests.

Answer are retured as instances of L<InteraxiomApi::Answer|InteraxiomApi::Answer>.

=head1 CLASS METHODS

=head2 Constructor

There is only one constructor: C<new>.

Its parameters are:

    Parameter           Mandatory                               Default                 Usage
    ------------        ------------                            ----------              --------
    type                Carp if missing                         API_MYACCOUNT()			Determine if you'll use european or canadian Interaxiom API (possible values are API_MYACCOUNT, API_PRIVATE and API_INTERNAL)
    timeout             No                                      10                      Set the timeout LWP::UserAgent will use
    applicationKey      Yes                                     -                       Your application key
    applicationSecret   Yes                                     -                       Your application secret
    consumerKey         Yes, unless for a credential request    -                       Your consumer key

=head2 API_MYACCOUNT

L<Constant|constant> that points to the root URL of Interaxiom customer API.

=head2 API_INTERNAL

L<Constant|constant> that points to the root URL of Interaxiom internal API.

=head2 API_PRIVATE

L<Constant|constant> that points to the root URL of Interaxiom private API.

=head2 setRequestTimeout

This method changes the timeout C<LWP::UserAgent> uses. You can set that in L<new|/Constructor> instead.

Its parameters are:

    Parameter           Mandatory
    ------------        ------------
    timeout             Yes

=head1 INSTANCE METHODS

=head2 rawCall

This is the main method of that wrapper. This method will take care of the signature, of the JSON conversion of your data, and of the effective run of the query.

Its parameters are:

    Parameter           Mandatory                               Default                 Usage
    ------------        ------------                            ----------              --------
    path                Yes                                     -                       The API URL you want to request
    method              Yes                                     -                       The HTTP method of the request (GET, POST, PUT, DELETE)
    body                No                                      ''                      The body to send in the query. Will be ignore on a GET
    noSignature         No                                      false                   If set to a true value, no signature will be send

=head2 get

Helper method that wraps a call to:

    rawCall(method => 'get");

All parameters are forwarded to L<rawCall|/rawCall>.

=head2 post

Helper method that wraps a call to:

    rawCall(method => 'post');

All parameters are forwarded to L<rawCall|/rawCall>.

=head2 put

Helper method that wraps a call to:

    rawCall(method => 'put');

All parameters are forwarded to L<rawCall|/rawCall>.

=head2 delete

Helper method that wraps a call to:

    rawCall(method => 'delete');

All parameters are forwarded to L<rawCall|/rawCall>.

=head1 SEE ALSO

The guts of module are using: C<LWP::UserAgent>, C<JSON>, C<Digest::SHA>.

=head1 COPYRIGHT

Copyright (c) 2026, Interaxiom.
All rights reserved.

This library is distributed under the terms of BSD 3-Clause License, see C<LICENSE>.

=cut
