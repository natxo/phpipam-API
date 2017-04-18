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
    $my $first_free =
      $ipam->get_free_first_address( token => $token, id => $subnet->{id} );

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

# other useragent string
$ua->transactor->name('perlbot/1.0 (https://github.com/natxo/phpipam-API)');

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
#  TODO: 
#  , add_child_subnet,
#   resize_subnet, split_subnet, set_subnet_perms,
#  del_subnet, truncate_subnet, reset_subnet_perms
#-------------------------------------------------------------------------------

=head2 get_subnet_by_id

get info on subnet providing its id.

Requires named arguments token and id (subnet id).

    my $subnet = $ipam->get_subnet_by_id( token => $token, id => $id );

=cut

sub get_subnet_by_id {
    my ( $self, %args ) = @_;
    my $token = $args{token};
    my $id    = $args{id};

    my $tx = $ua->get(
        "$prot://$url$api/subnets/$id/" => { 'token' => $args{token} } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die "Cannot get subnet $id: $err->{code} response -> $err->{message}";
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

=head2 get_free_first_address

get the first free available ip on subnet.

Requires named options (subnet) id and token.

    my $first = $ipam->get_free_first_address(
        token      => $token,
        id         => 7
    );

Returns the first available ip.

=cut

sub get_free_first_address {
    my ( $self, %args ) = @_;
    my $token = $args{token};
    my $id    = $args{id};

    #    my $first_free;

    my $tx = $ua->get(
        "$prot://$url$api/subnets/$id/first_free/" => { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die
"Cannot get first free address $err->{code} response -> $err->{message}";

    }

}    ## --- end sub free_first_address

=head2 get_subnet_addresses

get all ip addresses in the chosen subnet.

Requires named arguments token and id (subnet id).

    my $sub_addresses = $ipam->get_subnet_addresses( token => $token, id => 8, );

=cut

=head2 get_subnet_slaves

get all slaves of a subnet

Requires token and subnet id

my $slaves = $ipam->get_subnet_slaves(
    $token => $token,
    id     => $id,
    );

=cut

sub get_subnet_slaves {
    my ( $self, %args ) = @_;

    my $tx = $ua->get( "$prot://$url$api/subnets/$args{id}/slaves/" =>
          { 'token' => $args{token} } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die
"Cannot get slaves of subnet with id $args{id}: $err->{code} response -> $err->{message}";
    }

}

=head2 get_subnet_slaves_rec

get all slaves of a subnet recursively

Requires token and subnet id

my $slaves = $ipam->get_subnet_slaves_rec(
    $token => $token,
    id     => $id,
    );

=cut

sub get_subnet_slaves_rec {
    my ( $self, %args ) = @_;

    my $tx = $ua->get( "$prot://$url$api/subnets/$args{id}/slaves_recursive/" =>
          { 'token' => $args{token} } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die
"Cannot get slaves recursively of subnet with id $args{id}: $err->{code} response -> $err->{message}";
    }

}


=head2 get_subnets_customfields

get all custom fields in all subnets. Requires token.

my $cfs = $ipam->get_subnets_customfields( token => $token);

=cut

sub get_subnets_customfields {
    my ( $self, %args ) = @_;

    my $tx = $ua->get( "$prot://$url$api/subnets/custom_fields/" =>
          { 'token' => $args{token} } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die
"Cannot get all subnets custom fields: $err->{code} response -> $err->{message}";
    }

}


=head2 get_subnet_addresses

gets all addresses in subnet. Requires token en subnet id

    my $addrs = $ipam->get_subnet_addresses( token => $token, id => $id,);

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

=head2 get_1st_sub_with_mask

get the first subnet with $id and $mask.

Requires named arguments token, id and mask

    my $fist_sub = $ipam->get_1st_sub_with_mask(
        token => $token,
        id    => $id,
        mask  => $mask,
    );

=cut

sub get_1st_sub_with_mask {
    my ( $self, %args ) = @_;

    my $tx = $ua->get(
        "$prot://$url$api/subnets/$args{id}/first_subnet/$args{mask}/" =>
          { 'token' => $args{token} } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die
"Cannot get 1st subnet with id $args{id} and mask $args{mask}: $err->{code} response -> $err->{message}";
    }
}

=head2 get_all_subs_with_mask

get all subnets with selected mask mask.

Requires named arguments token, subnet id and mask

    my $fist_sub = $ipam->get_all subs_with_mask(
        token => $token,
        id    => $id,
        mask  => $mask,
    );

=cut

sub get_all_subs_with_mask {
    my ( $self, %args ) = @_;

    my $tx = $ua->get(
        "$prot://$url$api/subnets/$args{id}/all_subnets/$args{mask}/" =>
          { 'token' => $args{token} } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die
"Cannot get all subnet with id $args{id} and mask $args{mask}: $err->{code} response -> $err->{message}";
    }

}

=head2 search_subnet

get subnet info. Requires token, subnet and mask info.

    my $subnet = $ipam->search_subnet( $token, "192.168.0.0", "24" );

=cut

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

=head2 add_subnet

Add a subnet to phpipam.

Requires %args with the as keys the parameters specified in L<https://phpipam.net/api/api_documentation/#subnet>, at least token, subnet, mask and sectionId.

    my $newsubnet = $ipam->add_subnet(
        token       => $token,
        subnet      => "192.168.100.0",
        mask        => "24",
        sectionId   => "3",
        description => "none at all",
    );

=cut

sub add_subnet {
    my ( $self, %args ) = @_;
    my $token = $args{token};

    # cannot pass token as parameter in the controller
    delete( $args{token} );

    my $tx = $ua->post(
        "$prot://$url$api/subnets/" => { token => $token } => json =>
          {%args} );

    if ( $tx->success ) {
        print "Subnet $args{subnet} " . $tx->res->{'message'} . "\n";
        return $tx->res->content->asset->{content};
    }
    else {
        my $err = $tx->error;
        warn "Could not add subnet $err->{code}: "
          . $tx->res->json->{'message'};
        return $tx->res->json->{'message'};
    }
}

=head2 update_subnet

Update a subnet in phpipam.

Requires %args with the as keys the parameters specified in L<https://phpipam.net/api/api_documentation/#subnet>

=cut

sub update_subnet {
    my ( $sef, %args ) = @_;
    my $token = $args{token};
    #
    # cannot pass token as parameter in the controller
    delete( $args{token} );

    my $tx = $ua->patch(
        "$prot://$url$api/subnets/" => { token => $token } => json =>
          { %args, } );
    if ( $tx->success ) {
        return $tx->res->content->asset->{content};
    }
    else {
        my $err = $tx->error;
        warn "Could not update subnet $err->{code}: "
          . $tx->res->json->{'message'};
        return $tx->res->json->{'message'};
    }
}

=head2 resize_subnet

resize an existing subnet in phpipam.

Requires token, subnet id and mask.

    my $resized = $ipam->resize_subnet( token => $token, id => 18, mask => 29,);

=cut

sub resize_subnet {
    my ( $sef, %args ) = @_;
    my $token = $args{token};
    die "Need subnet id and mask to resize the subnet\n" unless defined $args{id} && defined $args{mask};

    # cannot pass token as parameter in the controller
    delete( $args{token} );

    my $tx = $ua->patch(
        "$prot://$url$api/subnets/$args{id}/resize/" => { token => $token } =>
          json => { %args, } );
    if ( $tx->success ) {
        return $tx->res->content->asset->{content};
    }
    else {
        my $err = $tx->error;
        warn "Could not resize subnet $err->{code}: "
          . $tx->res->json->{'message'};
        return $tx->res->json->{'message'};
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
