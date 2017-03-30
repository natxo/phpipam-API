package phpipam::API;

=head1 NAME

phpipam::API - Provides a Perl5 interface to the phpipam API (https://phpipam.net/api/api_documentation/ )

=head1 SYNOPSIS

    use phpipam::API;
    my $ipam = phpipam::API->new(
        proto       => "http",
        url         => "server.domain.tld/phpipam/api/",
        api         => "name_api_phpipam",
        user        => "user",
        password    => "password",
    );

    # log in, get a token
    my $token = $ipam->get_token;

    # get sections
    my $sections = $ipam->get_sections( $token );

    # get vlans
    my $vlans = $ipam->get_vlans( $token );

    # get subnets
    my $subnets = $ipam->get_subnets( id => $section{id}, token => $token, );

    # get first free ip address in subnet 
    $my $first_free( token => $token, id => $subnet->{id} );

    # add ip to subnet
    $ipam->add_ip(
        ip          => $first_free,
        token       => $token,
        subnetid    => $subnet->{id},
    );

=head1 DESCRIPTION

phpipam::API provides an interface to the phpipam REST API for perl5.

The goal is to support all the existing api controllers:

=over 4

=item *

sections

=item *

subnets

=item *

addresses

=item *

vlans

=item *

l2domains

=item *

vrfs

=item *

tools

=item *

prefix

=back

=head1 REQUIREMENTS

Mojo::UserAgent, part of Mojolicious, easiest installed with cpanm:

    cpanm Mojolicious --notest

=head1 INSTALLATION

This module has not (yet?) been released to the CPAN, but using it is simply a matter of setting lib/phpipam/API.pm in the same directory as the script. Then you can 

    use lib 'lib';
    use phpipam::API;

=head1 TODO

=over 2

=item *

document rest of implemented methods

=item *

security: right now only NONE is implemented. Hence use of tls connections strongly recommended (communications clear text over the wire otherwise).

=item *

implement new methods in version phpipam 1.3

=back

=head1 DEBUGGING

export the environment variable MOJO_USERAGENT_DEBUG=1 and run your perl script:

    export MOJO_USERAGENT_DEBUG=1
    ./script.pl 

You will be able to follow the whole http client/server conversation (it will post your encoded password so do not leave this variable enabled on your code.


=head1 METHODS

=cut

use strict;
use warnings;
use Mojo::UserAgent;

# web browser
my $ua = Mojo::UserAgent->new;

# follow location headers
$ua = $ua->max_redirects(5);

my %args;
my ( $url, $prot, $api, $user, $pass );

=head2 Constructor

    my $ipam = phpipam::API->new(
        proto => "http",
        url     => "server.domain.tld/phpipam/api/",
        api     => "name_api_phpipam",
        user    => "api user",
        password    => "password",
    );

Arguments:

All compulsory ;-)

=over 4

=item *

proto: http or https. Use https if possible, but not all webservers have implemented http redirection;

=item *

url: hostname part of uri (ip address or hostname.domain.tld) plus path to api url

    $url = "host.domain.tld/phpipam/api/";

In this case the phpipam instance is in the dir phpipam in the root of the webserver.

=item *

api: name of api specified in phpipam to access the api;

=item *

user: user allowed to access the specified api. At least read rights necessary;

=item *

password: self explanatory;

=back

=cut

sub new {
    my ( $class, %args ) = @_;
    $url  = $args{url};
    $prot = $args{proto};
    $api  = $args{api};
    $pass = $args{password};
    $user = $args{user};
    my $self = {
        url      => $url,
        proto    => $prot,
        api      => $api,
        user     => $user,
        password => $pass,
    };

    return bless( $self, $class );
}

#-------------------------------------------------------------------------------
#  Authentication user controller
#-------------------------------------------------------------------------------

=head2 get_token

See L<http://phpipam.net/api-documentation/#authentication> 

This method retrieves the authentication api token. If the request is not successful it dies

    my $token = $ipam->get_token;

=cut

#===  FUNCTION  ===============================================================
#
#         NAME: get_token
#      PURPOSE: retrieve api token
#   PARAMETERS: none
#      RETURNS: $token
#  DESCRIPTION: see http://phpipam.net/api-documentation/#authentication
#       THROWS: http://phpipam.net/api-documentation/#response_handling
#     COMMENTS: dies if response not succesful
#     SEE ALSO: n/a
#==============================================================================
sub get_token {
    my ( $self, %args ) = @_;

    my $url_com = "$prot://$user:$pass\@$url" . $api . "/user/";
    my $tx      = $ua->post($url_com);
    my $token;
    if ( my $res = $tx->success ) {
        $token = $tx->res->json->{data}->{token};
        return $token;
    }
    else {
        my $err = $tx->error;
        die "Could not get token:  $err->{code} response "
          . $tx->res->json('/message');
    }
}

=head2 get_token_expiration

    my $exp = $ipam->get_token_expiration( $token );

This method returns the token expiration date

The method requires the $token parameter.

=cut

#===  FUNCTION  ================================================================
#         NAME: get_token_expiration
#      PURPOSE: retrieve token expiration date
#   PARAMETERS: $token
#      RETURNS: $exp with expiration date
#  DESCRIPTION: see http://phpipam.net/api-documentation/#authentication
#       THROWS: http://phpipam.net/api-documentation/#response_handling
#     COMMENTS: dies on http error
#     SEE ALSO: n/a
#===============================================================================
sub get_token_expiration {
    my ( $self, $token ) = @_;
    my $exp;
    die "Need token\n" unless defined $token;

    my $tx = $ua->get(
        "$prot://$url$api/user/token_expires/" => { 'token' => $token } );

    if ( $tx->success ) {
        $exp = $tx->res->json('/data');
        return $exp->{'expires'};
    }
    else {
        my $err = $tx->error;
        die "Could not get expiration date of token:  $err->{code} response "
          . $tx->res->json('/message');
    }
}    ## --- end sub get_token_expiration

=head2 get_all_users

Retrieve a list of all users (requires rwa permissions on the api)

    my $users = $ipam->get_all_users( $token );

Returns an array reference of hashes with the user info.

The method requires the $token parameter.

=cut

#===  FUNCTION  ================================================================
#         NAME: get_all_users
#      PURPOSE: get list of all users
#   PARAMETERS: $token
#      RETURNS: array ref of hashes
#  DESCRIPTION: see http://phpipam.net/api-documentation/#authentication
#       THROWS: http://phpipam.net/api-documentation/#response_handling
#     COMMENTS: dies on http error, requires api rwa rights
#     SEE ALSO: n/a
#===============================================================================
sub get_all_users {
    my ( $self, $token ) = @_;
    my $allusers;
    die "Need token\n" unless defined $token;

    my $tx = $ua->get( "$prot://$url$api/user/all/" => { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die "Could not get info on all users:  $err->{code} response "
          . $tx->res->json('/message');
    }
}    ## --- end sub get_all_users

=head2 delete_token

Remove the api token.

    $ipam->delete_token( $token );

If assigned to a scalar variable, it returns a json string with info.

The method requires the $token parameter.

=cut

#===  FUNCTION  ================================================================
#         NAME: delete_token
#      PURPOSE: delete api session token
#   PARAMETERS: $token
#      RETURNS: array ref with http message
#  DESCRIPTION: delete api session token
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub delete_token {
    my ( $self, $token ) = @_;
    die "Need token to delete_token\n" unless defined $token;

    my $tx = $ua->delete( "$prot://$url$api/user/" => { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data')->[0];
    }
    else {
        my $err = $tx->error;
        die "Could not delete token!  $err->{code} "
          . $tx->res->json('/message');
    }
}    ## --- end sub delete_token

#-------------------------------------------------------------------------------
#  Authorization (permissions)
#-------------------------------------------------------------------------------

=head2 get_rights

Retrieve the rights of the logged in api user

    my $rights = $ipam->get_rights( $token );

Returns a hash ref with 2 keys, one for the permissions and one for controllers.

=cut

#===  FUNCTION  ================================================================
#         NAME: get_rights
#      PURPOSE: get rights of logged in api user
#   PARAMETERS: token
#      RETURNS: hash reference with 2 keys: controllers and permissions
#  DESCRIPTION: see name
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub get_rights {
    my ( $self, $token ) = @_;

    my $tx = $ua->options( "$prot://$url$api/" => { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        warn "cannot get rights, error: $err->{code} "
          . $tx->res->json->{message}, "\n";

    }
}

#-------------------------------------------------------------------------------
#  Sections controller
#-------------------------------------------------------------------------------

=head2 get_sections

Retrieve info on a specific section. See L<http://phpipam.net/api-documentation/#sections>.

Returns: array of hashes reference

Requires: token

    my $section = $ipam->get_sections( $token );

=cut

#===  FUNCTION  ================================================================
#         NAME: get_sections
#      PURPOSE: retrieves sections
#   PARAMETERS: $token
#      RETURNS: $sections array of hashes ref
#  DESCRIPTION: see comments
#       THROWS: dies on http errors
#     COMMENTS: http://phpipam.net/api-documentation/#sections
#     SEE ALSO: n/a
#===============================================================================
sub get_sections {
    my ( $self, $token ) = @_;
    my $sections;
    die "Need token\n" unless defined $token;

    my $tx = $ua->get( "$prot://$url$api/sections/" => { 'token' => $token } );

    if ( $tx->success ) {
        $sections = $tx->res->json('/data');
        return $sections;
    }
    else {
        my $err = $tx->error;
        die "Could not get sections:  $err->{code} response "
          . $tx->res->json('/message');

    }
}    ## --- end sub get_sections

=head2 get_sections

Retrieve the sections available in the phpipam instance. See L<http://phpipam.net/api-documentation/#sections>.

Returns: hashes reference

Requires: %args with token and either id or name.

    my $section = $ipam->get_section( token => $token, id => $id );

or

    my $section = $ipam->get_section( token => $token, name => "name" );

=cut

#===  FUNCTION  ================================================================
#         NAME: get_section
#      PURPOSE: retrieve info on specific section
#   PARAMETERS: $token and ( $id or $name )
#   PARAMETERS: %args, token and (id or name) compulsary
#      RETURNS: hash ref with section info
#  DESCRIPTION: retrieve info on specific section
#       THROWS: no exceptions
#     COMMENTS: only one of $id or $name is allowed
#     SEE ALSO: n/a
#===============================================================================
sub get_section {
    my ( $self, %args ) = @_;
    my $token = $args{token};

    die "sorry, only one of id or name allowed, not both\n"
      if defined $args{id} and defined $args{name};

    my ( $section, $tx );
    if ( defined $args{id} ) {
        $tx =
          $ua->get(
            "$prot://$url$api/sections/$args{id}/" => { 'token' => $token } );
    }
    elsif ( defined $args{name} ) {
        $tx =
          $ua->get(
            "$prot://$url$api/sections/$args{name}/" => { 'token' => $token } );
    }
    if ( $tx->success ) {
        $section = $tx->res->json('/data');
        return $section;
    }
    else {
        my $err = $tx->error;
        warn "Cannot get section info $err->{code}";
        return $tx->res->json('message');
    }

}    ## --- end sub get_section

=head2 add_section

Add a section to phpipam.

Requires %args with the as keys the parameters specified in L<https://phpipam.net/api/api_documentation/#sections>

    my $newsection = $ipam->add_section(
        token       => $token,
        name        => "whatever",
        description => "none at all",
        showVLAN    => 1,
    );

=cut

#===  FUNCTION  ================================================================
#         NAME: add_section
#      PURPOSE: add a section to phpipam
#   PARAMETERS: %args with as keys the accepted parameters for the post
#               method of the section conotroller
#      RETURNS: json object with message info
#  DESCRIPTION:
#       THROWS: no exceptions
#     COMMENTS: token and name are compulsory.
#     SEE ALSO: n/a
#===============================================================================
sub add_section {
    my ( $self, %args ) = @_;
    my $token = $args{token};

    # cannot pass token as parameter in the controller
    delete( $args{token} );

    my $section;
    my $tx = $ua->post(
        "$prot://$url$api/sections/" => { token => $token } => json =>
          {%args} );

    if ( $tx->success ) {
        print "Section $args{name} " . $tx->res->{'message'};
        print ", address " . $tx->res->content->headers->location, "\n";
        return $tx->res->content->asset->{content};
    }
    else {
        my $err = $tx->error;
        warn "Could not add section $err->{code}: "
          . $tx->res->json->{'message'};
        return $tx->res->json->{'message'};
    }
}

=head2 del_section

removes a section from phpipam. Requires token and id.

    $ipam->del_section( token => $token, id => $id, );

Returns a json message on error/success.

=cut

sub del_section {
    my ( $self, %args ) = @_;
    my $token = $args{token};
    my $id    = $args{id};
    die "sorry, without a token we cannot query the phpipam api\n"
      unless $token;

    my $section;
    my $tx = $ua->delete(
        "$prot://$url$api/sections/" => { token => $token } => json => {
            id => $id,
        }
    );

    if ( $tx->success ) {
        return $tx->res->content->asset->{content};
    }
    else {
        my $err = $tx->error;
        warn "Could not remove section $err->{code}: "
          . $tx->res->json->{'message'};
        return $tx->res->json->{'message'};
    }

}

=head2 update_section

Update a section to phpipam.

Requires %args with the as keys the parameters specified in L<https://phpipam.net/api/api_documentation/#sections>, token and id are compulsory.

    my $update = $ipam->update_section(
        token      => $token,
        id         => $section->{'id'},
        strictMode => '1',
        showVRF    => '1',
        description => 'your little pony',
    );

=cut

#===  FUNCTION  ================================================================
#         NAME: update_section
#      PURPOSE: update details section controller
#   PARAMETERS: %args with as keys the accepted parameters for the patch
#               method of the section conotroller
#      RETURNS: http success/error codes
#  DESCRIPTION:
#       THROWS: no exceptions
#     COMMENTS: token and id are compulsory.
#     SEE ALSO: n/a
#===============================================================================
sub update_section {
    my ( $sef, %args ) = @_;
    my $token = $args{token};
    #
    # cannot pass token as parameter in the controller
    delete( $args{token} );

    my $section;
    my $tx = $ua->patch(
        "$prot://$url$api/sections/" => { token => $token } => json =>
          { %args, } );
    if ( $tx->success ) {
        return $tx->res->content->asset->{content};
    }
    else {
        my $err = $tx->error;
        warn "Could not update section $err->{code}: "
          . $tx->res->json->{'message'};
        return $tx->res->json->{'message'};
    }
}

=head2 get_subnets

get available subnets in a section.

Requires named arguments token and id (section id).

    my $subnets =
        $ipam->get_subnets( token => $token, id => 3,) ;

Returns an array reference of hashes containing the subnet info.

=cut

#===  FUNCTION  ================================================================
#         NAME: get_subnets
#      PURPOSE: retrieve the available subnets in a section
#   PARAMETERS: id => "section id", token => $token
#      RETURNS: array ref with hashes containing the subnet info
#  DESCRIPTION:
#       THROWS: on error dies with http codes
#     COMMENTS: none
#     SEE ALSO: get_sections
#===============================================================================
sub get_subnets {
    my ( $self, %args ) = @_;
    my $id    = $args{id};
    my $token = $args{token};

    die "sorry, we require a section id to get a list of subnets\n" unless $id;
    die "sorry, without a token we cannot query the phpipam api\n"
      unless $token;

    my $subnets;
    my $tx = $ua->get(
        "$prot://$url$api/sections/$id/subnets/" => { 'token' => $token } );

    if ( $tx->success ) {
        $subnets = $tx->res->json('/data');
        return $subnets;
    }
    else {
        my $err = $tx->error;
        warn "Cannot get subnet: $err->{code} response -> $err->{message}";

    }

}    ## --- end sub get_subnets

#-------------------------------------------------------------------------------
#  Subnets controller
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
#  TODO: get_subnet_slaves,
#  get_subnet_slave_rec, get_subnet_address,
#  get_first_subnet, get_all_subnets, add_subnet, add_child_subnet,
#  update_subnet, resize_subnet, split_subnet, set_subnet_perms,
#  del_subnet, truncate_subnet, reset_subnet_perms
#-------------------------------------------------------------------------------

=head2 get_subnet_addresses

get all ip addresses in the chosen subnet.

Requires named arguments token and id (subnet id).

    my $sub_addresses = $ipam->get_subnet_addresses( token => $token, id => 8, );

=cut

sub get_subnet_addresses {
    my ( $self, %args ) = @_;

    my $tx = $ua->get( "$prot://$url$api/subnets/$args{id}/addresses/" =>
          { 'token' => $args{token} } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die "Cannot get subnet usage: $err->{code} response -> $err->{message}";
    }

}

=head2 get_subnet_usage

get info on usage of the specific subnet.

Requires named arguments token and id (subnet id).

    my $sub_usage = $ipam->get_subnet_usage( token => $token, id => 8, );

=cut

sub get_subnet_usage {
    my ( $self, %args ) = @_;

    my $tx = $ua->get( "$prot://$url$api/subnets/$args{id}/usage/" =>
          { 'token' => $args{token} } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die "Cannot get subnet usage: $err->{code} response -> $err->{message}";
    }

}

=head2 free_first_address

get the first free available ip on subnet.

Requires named options (subnet) id and token.

    my $first = $ipam->free_first_address(
        token      => $token,
        id         => 7
    );

Returns the first available ip.

=cut

#===  FUNCTION  ================================================================
#         NAME: free_first_address
#      PURPOSE: get 1st available address
#   PARAMETERS: id => 'subnet id', token => $token
#      RETURNS: $first_free
#  DESCRIPTION: get first free available ip on subnet
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub free_first_address {
    my ( $self, %args ) = @_;
    my $token = $args{token};
    my $id    = $args{id};

    #    my $first_free;

    my $tx = $ua->get(
        "$prot://$url$api/subnets/$id/first_free/" => { 'token' => $token } );

    if ( $tx->success ) {

        #        $first_free = $tx->res->json('/data');
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die
"Cannot get first free address $err->{code} response -> $err->{message}";

    }

}    ## --- end sub free_first_address

=head2 search_subnet

get subnet info. Requires token, subnet and mask info.

    my $subnet = $ipam->search_subnet( $token, "192.168.0.0", "24" );

=cut

#===  FUNCTION  ================================================================
#         NAME: search_subnet
#      PURPOSE: get subnet info
#   PARAMETERS: token, subnet, mask
#      RETURNS: array ref with hash describing subnet
#  DESCRIPTION: see name
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub search_subnet {
    my ( $self, $token, $subnet, $mask ) = @_;
    die "Sorry, no token found\n" unless defined $token;
    die "Sorry, subnet and mask are required arguments\n"
      if !defined $subnet or !defined $mask;

    my $net;
    my $tx = $ua->get(
        "$prot://$url$api/subnets/cidr/$subnet/$mask/" => { 'token' => $token }
    );

    if ( $tx->success ) {
        $net = $tx->res->json('/data');
        return $net;
    }
    else {
        my $err = $tx->error;
        die warn "cannot find subnet $subnet/$mask, error: $err->{code} "
          . $tx->res->json->{message}, "\n";

    }
}

#-------------------------------------------------------------------------------
#  Address controller
#-------------------------------------------------------------------------------

=head2 add_ip

add an ip to a subnet. Requires at least the token, the ip address and
the subnetid.

Other optional named parameters can be found in the address controller
documenation L<https://phpipam.net/api/api_documentation#addresses>. Warning:
the name of the paremeters is case sensitive.

    $ipam->add_ip( token => $token, ip => $first, subnetId => "7", );

=cut

#===  FUNCTION  ================================================================
#         NAME: add_ip
#      PURPOSE: add ip address to ipam
#   PARAMETERS: token, subnetid, ip, hostname, mac, owner, description
#      RETURNS: if successfully added, location header on stdout with ip
#      info
#  DESCRIPTION: see name
#       THROWS: no exceptions
#     COMMENTS:
#     SEE ALSO: n/a
#===============================================================================
sub add_ip {
    my ( $self, %args ) = @_;
    my $token = $args{token};

    # cannot pass token as parameter in the controller
    delete( $args{token} );

    die "I need both the ip address as the subnet id\n"
      if !defined $args{ip}
      or !defined $args{subnetId};

    my $tx = $ua->post(
        "$prot://$url$api/addresses/" => { 'token' => $token } => json =>
          {%args} );

    if ( $tx->success ) {
        print "$args{ip} successfully added\n";
    }
    else {
        my $err = $tx->error;
        warn "cannot add $args{ip}, error: $err->{code} "
          . $tx->res->json->{message},
          "\n";
    }

}

=head2 delete_ip

remove ip address from phpipam. Requires token en the ip id.

You can get the ip id using search_ip. 

    my $ipaddr = $ipam->search_ip(
        token => $token,
        ip => $first,
    );
    
    if ( scalar @$ipaddr == 1 ) {
        print "$first has id: $$ipaddr[0]->{id}\n";
        $ipam->delete_ip( token => $token, ip_id => $$ipaddr[0]->{id} );
    }

=cut

#===  FUNCTION  ================================================================
#         NAME: delete_ip
#      PURPOSE: remove ip from phpipam
#   PARAMETERS: token, ip_id
#      RETURNS:
#  DESCRIPTION:
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub delete_ip {
    my ( $self, %args ) = @_;
    my $token = $args{token};
    my $ip_id = $args{ip_id};

    die "I need both the ip id as the token\n"
      if !defined $token or !defined $ip_id;

    my $tx = $ua->delete(
        "$prot://$url$api/addresses/$ip_id/" => { 'token' => $token } );

    if ( $tx->success ) {
        print "$ip_id successfully deleted\n";
    }
    else {
        my $err = $tx->error;
        warn "cannot delete $ip_id, error: $err->{code} "
          . $tx->res->json->{message}, "\n";
    }
}

=head2 search_hostname

lookup addresses in phpipam database. Requires token and hostname

    my $name = $ipam->search_hostname( token => $token, hostname => $hostname);

=cut

#===  FUNCTION  ================================================================
#         NAME: search_hostname
#      PURPOSE: lookup hostname info if already availble in phpipam
#   PARAMETERS: host => "hostname", token => $token
#      RETURNS: array ref with hashes containing the host info, 404 if
#      nothing found
#  DESCRIPTION:
#       THROWS: on error dies with http codes
#     COMMENTS: none
#     SEE ALSO: get_sections
#===============================================================================
sub search_hostname {
    my ( $self, %args ) = @_;
    my $token = $args{token};
    my $host  = $args{host};

    die "I need both the hostname as the token\n"
      if !defined $token or !defined $host;

    my $tx = $ua->get( "$prot://$url$api/addresses/search_hostname/$host/" =>
          { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        warn "cannot find host $host, error: $err->{code} "
          . $tx->res->json->{message}, "\n";
    }
}

=head2 search_ip

find ip details in phpipam. Requires token and ip.

    my $ipaddr = $ipam->search_ip(
        token => $token,
        ip => $first,
    );

It returns an array ref of hashes

=cut

#===  FUNCTION  ================================================================
#         NAME: search_ip
#      PURPOSE: find ip details in phpipam
#   PARAMETERS: token, ip
#      RETURNS: array ref of hashes
#  DESCRIPTION:
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub search_ip {
    my ( $self, %args ) = @_;
    my $token = $args{token};
    my $ip    = $args{ip};

    die "I need both the token as the ip\n"
      if !defined $token or !defined $ip;

    my $tx = $ua->get(
        "$prot://$url$api/addresses/search/$ip/" => { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die "cannot search $ip, error: $err->{code} "
          . $tx->res->json->{message}, "\n";
    }
}    ## --- end sub search_ip

=head2 get_addrs_subnet

get addresess on subnet. Requires token and subnet id. Returns an array ref of hashes.

    my $addrs = $ipam->get_addrs_subnet( token => $token, subnetid => $id );

=cut

#===  FUNCTION  ================================================================
#         NAME: get_addrs_subnet
#      PURPOSE: get info addresses in subnet
#   PARAMETERS: token, subnetid
#      RETURNS: array of hashes
#  DESCRIPTION:
#       THROWS:
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub get_addrs_subnet {
    my ( $self, %args ) = @_;
    my $token    = $args{token};
    my $subnetid = $args{subnetid};

    die "I need both the subnet id as the token\n"
      if !defined $token or !defined $subnetid;

    my $tx = $ua->get( "$prot://$url$api/subnets/$subnetid/addresses/" =>
          { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die "cannot find addresses in subnet $subnetid error: $err->{code} "
          . $tx->res->json->{message}, "\n";
    }

}

=head2 get_ip_tags

retrieves all ip tags from phpipam. Requires token.

    my $tags = $ipam->get_ip_tags( token => $token );

=cut

#===  FUNCTION  ================================================================
#         NAME: get_ip_tags
#      PURPOSE: retrieve all ip tags from phpipam
#   PARAMETERS: $token
#      RETURNS: all ip tags
#  DESCRIPTION:
#       THROWS: no exceptions
#     COMMENTS: not working yet, see https://github.com/phpipam/phpipam/issues/632
#     SEE ALSO: n/a
#===============================================================================
sub get_ip_tags {
    my ( $self, %args ) = @_;
    my $token = $args{token};

    die "I need both the the token\n"
      if !defined $token;

    my $tx =
      $ua->get( "$prot://$url$api/tools/tags/" => { 'token' => $token } );

 #      $ua->get( "$prot://$url$api/addresses/tags/" => { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die "cannot find ip tags $err->{code} " . $tx->res->json->{message},
          "\n";
    }

}

=head2 get_ips_tag

get ips assigned to tag id. Requires token and tag id. Returns an array
ref of hashes

    my $dhcp = $ipam->get_ips_tag( token => $token, tagid => "4",);

=cut

#===  FUNCTION  ================================================================
#         NAME: get_ips_tag
#      PURPOSE: retrieve ips assigned to tag id
#   PARAMETERS: token, tagid
#      RETURNS: array ref with hashes
#  DESCRIPTION:
#       THROWS: http errors
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub get_ips_tag {
    my ( $self, %args ) = @_;
    my $token = $args{token};
    my $tagid = $args{tagid};

    die "I need both the the token and the tag id\n"
      if !defined $token or !defined $tagid;

    my $tx = $ua->get( "$prot://$url$api/tools/tags/$tagid/addresses/" =>
          { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        warn "cannot find ip tags $err->{code} " . $tx->res->json->{message},
          "\n";
    }

}    ## --- end sub get_ips_tag

#-------------------------------------------------------------------------------
#  Vlans controller
#-------------------------------------------------------------------------------

=head2 get_vlans

retrieve all vlans in phpipam. Requires token, returns array ref of hashes.

    my $vlans = $ipam->get_vlans($token);

=cut

sub get_vlans {
    my ( $self, $token ) = @_;
    my $vlans;
    die "Need token\n" unless defined $token;

    my $tx =
      $ua->get( "$prot://$url$api/tools/vlans/" => { 'token' => $token } );

    if ( $tx->success ) {
        $vlans = $tx->res->json('/data');
        return $vlans;
    }
    else {
        my $err = $tx->error;
        die "Could not get vlans $err->{code} $tx->res->json->{message}";

    }
}    ## --- end sub get_vlans

sub get_racks {
    my ( $self, $token ) = @_;
    my $racks;
    die "Need token\n" unless defined $token;

    my $tx =
      $ua->get( "$prot://$url$api/tools/racks/" => { 'token' => $token } );

    if ( $tx->success ) {
        $racks = $tx->res->json('/data');
        return $racks;
    }
    else {
        my $err = $tx->error;
        die "Could not get racks $err->{code} $tx->res->json->{message}";

    }
}    ## --- end sub get_racks

#-------------------------------------------------------------------------------
#  L2 domains controller
#-------------------------------------------------------------------------------

=head2 get_l2domains

Retrieves all vlan domains/l2domains. Requires token, returns an array
ref of hashes

    my $l2domains = $ipam->get_l2domains($token);

=cut

sub get_l2domains {
    my ( $self, $token ) = @_;
    my $l2domains;
    die "Need token\n" unless defined $token;

    my $tx = $ua->get( "$prot://$url$api/l2domains/" => { 'token' => $token } );

    if ( $tx->success ) {
        $l2domains = $tx->res->json('/data');
        return $l2domains;
    }
    else {
        my $err = $tx->error;
        die "Could not get l2domains $err->{code} response -> $err->{message}";

    }
}    ## --- end sub get_l2domains

=head1 ACKNOWLEDGEMENTS

Thanks to the developers of phpipam for a great product, the maintainers of the Perl language and Mojolicious for making this easily possible

=cut

1;
