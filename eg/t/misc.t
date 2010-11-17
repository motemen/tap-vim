#!perl
use strict;
use Test::More tests => 10;

pass;
fail;
pass 'foo';
fail 'bar';

local $TODO = 'reason';
fail;
fail 'baz';
diag explain { a => 1, b => 2 };

subtest 'subtest' => sub {
    pass;
    fail;
};

SKIP: {
    skip reason => 2;
    fail;
    fail 'qux'
}
