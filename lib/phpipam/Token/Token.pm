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

1;
