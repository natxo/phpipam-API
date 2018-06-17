use strict;
use warnings;

package phpipam::Section::Section;
# object inheritance
use parent 'phpipam::API';

# import package variables from phpipam::API
use phpipam::API qw( $ua $url $prot $api $pass $user);

# section controller methods

#-------------------------------------------------------------------------------
#  Sections controller
#-------------------------------------------------------------------------------

=head2 SECTIONs

=head3 B<get_sections>

Retrieve the sections available in the phpipam instance. See L<http://phpipam.net/api-documentation/#sections>.

Returns: hashes reference

Requires: token

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

sub get_section {
    my ( $self, %args ) = @_;
    my $token = $args{token};

    die "sorry, get_section allows only one of id or name, not both\n"
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

=head3 B<add_section>

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

=head3 B<del_section>

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

=head3 B<update_section>

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
1; 
