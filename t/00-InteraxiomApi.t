use strict;
use warnings;

use Test::More;

use_ok('InteraxiomApi');

subtest '_getTarget' => sub {
    is(InteraxiomApi::_getTarget(InteraxiomApi::API_MYACCOUNT(), '/v1/me'), 'https://api.interaxiom.com.au/myaccount/v1/me');
};

done_testing;
