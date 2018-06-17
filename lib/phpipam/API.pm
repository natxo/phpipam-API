use strict;
use warnings;
use Mojo::UserAgent;

package phpipam::API;
use Exporter;

our ( $ua, $url, $prot, $api, $pass, $user );
our @ISA       = 'Exporter';
our @EXPORT_OK = qw( $ua $url $prot $api $pass $user );

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

# web browser
$ua = Mojo::UserAgent->new;

# other useragent string
$ua->transactor->name('perlbot/1.0 (https://github.com/natxo/phpipam-API)');

# follow location headers
$ua = $ua->max_redirects(5);

1;
