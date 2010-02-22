#!perl

use Test::More;

use lib 't/lib';
use DBICTest;
use DBIx::Class::DeploymentHandler;

my $handler = DBIx::Class::DeploymentHandler->new({
   schema => DBICTest->init_schema()
});

ok($handler, 'DBIx::Class::DeploymentHandler instantiates correctly');

done_testing;
