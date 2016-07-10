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
    $url = $args{url};
    $prot = $args{proto};
    $api = $args{api};
    $pass = $args{password};
    $user = $args{user};
    my $self = {
        url      => $args{url},
        proto    => $args{prot},
        api      => $args{api},
        user     => $args{user},
        password => $args{pass},
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
#      RETURNS: $sections array of hasshes ref
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
#   PARAMETERS: id => 'section id', token => $token
#      RETURNS: $first_free
#  DESCRIPTION: ????
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
        die "Cannot get rights $err->{code} response -> $err->{message}";

    }
}

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
        die
"Cannot find subnet $subnet/$mask: $err->{code} response -> $err->{message}";

    }
}

sub add_ip {
    my ( $self, %args ) = @_;
    my $token    = $args{token};
    my $subnetid = $args{subnetid};
    my $ip       = $args{ip};
    my $mask     = $args{mask};
    my $hostname = $args{hostname};
    my $macaddr  = $args{macaddr};

    die "I need both the ip address as the subnet id\n"
      if !defined $ip or !defined $subnetid;

    my $tx = $ua->post(
        "$prot://$url$api/addresses/" => { 'token' => $token } => json => {
            'ip'       => $ip,
            'subnetId' => $subnetid,
        }
    );
    if ( $tx->success ) {
        print "$ip successfully added\n";
        print $tx->res->content->headers->location, "\n";
    }
    else {
        my $err = $tx->error;
        die "cannot add $ip $err->{code} response -> $err->{message}";
    }

}

sub delete_ip {
    my ( $self, %args ) = @_;
    my $token = $args{token};
    my $ip_id = $args{ip_id};

    die "I need both the ip id as the token\n"
      if !defined $token or !defined $ip_id;

    my $tx = $ua->delete(
        "$prot://$url$api/addresses/$ip_id/" => { 'token' => $token }
    );

    if ( $tx->success ) {
        print "$ip_id successfully deleted\n";
    }
    else {
        my $err = $tx->error;
        die "cannot delete $ip_id $err->{code} response -> $err->{message}";
    }
}

1;
