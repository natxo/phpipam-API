use strict;
use warnings;

package phpipam::Subnets::Subnets;

# object inheritance
use parent 'phpipam::API';

# import package variables from phpipam::API
use phpipam::API qw( $ua $url $prot $api $pass $user);

# subnets controller methods

=head2 SUBNETS

=head3 B<get_subnets>

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

=head3 B<get_subnet_by_id>

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

=head3 B<get_subnet_usage>

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

=head3 B<get_free_first_address>

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

=head3 B<get_subnet_addresses>

get all ip addresses in the chosen subnet.

Requires named arguments token and id (subnet id).

    my $sub_addresses = $ipam->get_subnet_addresses( token => $token, id => 8, );

=cut

=head3 B<get_subnet_slaves>

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

=head3 B<get_subnet_slaves_rec>

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

=head3 B<get_subnets_customfields>

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

=head3 B<get_subnet_addresses>

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

=head3 B<get_1st_sub_with_mask>

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

=head3 B<get_all_subs_with_mask>

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

=head3 B<search_subnet>

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

=head3 B<add_subnet>

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
        "$prot://$url$api/subnets/" => { token => $token } => json => {%args} );

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

=head3 B<update_subnet>

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

=head3 B<resize_subnet>

resize an existing subnet in phpipam.

Requires token, subnet id and mask.

    my $resized = $ipam->resize_subnet( token => $token, id => 18, mask => 29,);

=cut

sub resize_subnet {
    my ( $sef, %args ) = @_;
    my $token = $args{token};
    die "Need subnet id and mask to resize the subnet\n"
      unless defined $args{id} && defined $args{mask};

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

1;
