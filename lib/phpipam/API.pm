package phpipam::API;

use strict;
use warnings;
use Mojo::UserAgent;

# web browser
my $ua = Mojo::UserAgent->new;

# follow location headers
$ua = $ua->max_redirects(5);

my %args;
my ( $url, $prot, $api, $user, $pass );

# constructor
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
        die "Could not get token: $err->{code} response -> $err->{message}";
    }
}

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
        die "Could not get sections $err->{code} response -> $err->{message}";

    }
}    ## --- end sub get_sections

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
    my $first_free;

    my $tx = $ua->get(
        "$prot://$url$api/subnets/$id/first_free/" => { 'token' => $token } );

    if ( $tx->success ) {
        $first_free = $tx->res->json('/data');
        return $first_free;
    }
    else {
        my $err = $tx->error;
        die
"Cannot get first free address $err->{code} response -> $err->{message}";

    }

}    ## --- end sub free_first_address


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

    my $rights;
    my $tx = $ua->options( "$prot://$url$api/" => { 'token' => $token } );

    if ( $tx->success ) {
        $rights = $tx->res->json('/data');
        return $rights;
    }
    else {
        my $err = $tx->error;
        warn "cannot get rights, error: $err->{code} "
          . $tx->res->json->{message}, "\n";

    }
}


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
    my $token       = $args{token};
    my $subnetid    = $args{subnetid};
    my $ip          = $args{ip};
    my $mask        = $args{mask};
    my $hostname    = $args{hostname};
    my $macaddr     = $args{macaddr};
    my $owner       = $args{owner};
    my $description = $args{description};

    die "I need both the ip address as the subnet id\n"
      if !defined $ip or !defined $subnetid;

    my $tx = $ua->post(
        "$prot://$url$api/addresses/" => { 'token' => $token } => json => {
            'ip'          => $ip,
            'subnetId'    => $subnetid,
            'hostname'    => $hostname,
            'mac'         => $macaddr,
            'owner'       => $owner,
            'description' => $description,
        }
    );

    if ( $tx->success ) {
        print "$ip successfully added\n";
        print $tx->res->content->headers->location, "\n";
    }
    else {
        my $err = $tx->error;
        warn "cannot add $ip, error: $err->{code} " . $tx->res->json->{message},
          "\n";
    }

}


#===  FUNCTION  ================================================================
#         NAME: delete_ip
#      PURPOSE: remove ip from ipa 
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

    my $tx = $ua->get(
        "$prot://$url$api/addresses/search_hostname/$host/" => { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        warn "cannot find host $host, error: $err->{code} "
          . $tx->res->json->{message}, "\n";
    }
}


#===  FUNCTION  ================================================================
#         NAME: search_ip
#      PURPOSE: find ip details in ipam
#   PARAMETERS: token, ip
#      RETURNS: array of hashes ref
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

    my $tx = $ua->get( "$prot://$url$api/addresses/search/$ip/" =>
          { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die "cannot search $ip, error: $err->{code} "
          . $tx->res->json->{message}, "\n";
    }
}    ## --- end sub search_ip


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
        die
"cannot find addresses in subnet $subnetid $err->{code} response -> $err->{message}";
    }

}

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
      $ua->get( "$prot://$url$api/addresses/tags/" => { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        die "cannot find ip tags $err->{code} response -> $err->{message}";
    }

}

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

    my $tx = $ua->get( "$prot://$url$api/addresses/tags/$tagid/addresses/" =>
          { 'token' => $token } );

    if ( $tx->success ) {
        return $tx->res->json('/data');
    }
    else {
        my $err = $tx->error;
        warn "cannot find ip tags $err->{code} response -> $err->{message}";
    }

}    ## --- end sub get_ips_tag

sub get_vlans {
    my ( $self, $token ) = @_;
    my $vlans;
    die "Need token\n" unless defined $token;

    my $tx = $ua->get( "$prot://$url$api/tools/vlans/" => { 'token' => $token } );

    if ( $tx->success ) {
        $vlans = $tx->res->json('/data');
        return $vlans;
    }
    else {
        my $err = $tx->error;
        die "Could not get vlans $err->{code} response -> $err->{message}";

    }
}    ## --- end sub get_vlans

sub get_racks {
    my ( $self, $token ) = @_;
    my $racks;
    die "Need token\n" unless defined $token;

    my $tx = $ua->get( "$prot://$url$api/tools/racks/" => { 'token' => $token } );

    if ( $tx->success ) {
        $racks = $tx->res->json('/data');
        return $racks;
    }
    else {
        my $err = $tx->error;
        die "Could not get racks $err->{code} response -> $err->{message}";

    }
}    ## --- end sub get_racks

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
1;
