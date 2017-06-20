use strict;
use warnings;
use Data::Dumper;

use Test::More;
use Test::Exception;

# verify we can load via use pragma
use_ok 'phpipam::API';

# verify we can load via require pragma
require_ok('phpipam::API');


my $ipam = phpipam::API->new(
    proto    => 'http',
    url      => 'host.domain.tld',
    api      => 'myawesomeapi',
    user     => 'usera',
    password => 'pwd',
);

isa_ok $ipam, 'phpipam::API';

ok $ipam->{proto} eq 'http', 'protocol parameter was set correctly to http';
ok $ipam->{url} eq 'host.domain.tld',
  'url parameter was set correctly to host.domain.tld';

ok $ipam->{api} eq 'myawesomeapi', 'api parameter was set correctly';
ok $ipam->{password} eq 'pwd',     'password parameter was set correctly';

my @methods =
  qw(get_token get_token_expiration get_all_users get_rights get_sections get_section add_section del_section update_section get_subnets);

can_ok $ipam, @methods;

dies_ok { $ipam->get_token ; } "this should fail, no access to a real phpipam instance";

done_testing;
