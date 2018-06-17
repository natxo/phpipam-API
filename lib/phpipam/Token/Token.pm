use strict;
use warnings;

package phpipam::Token::Token;

# object inheritance
use parent
  qw( phpipam::API phpipam::Section::Section phpipam::Subnets::Subnets );

# import package variables from phpipam::API
use phpipam::API qw( $ua $url $prot $api $pass $user);

# controller methods
sub get_token {
    my ($self) = @_;

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

=head3 B<delete_token>
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

1;
