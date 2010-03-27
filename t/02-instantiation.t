#!perl

use lib 't/lib';
use DBICDHTest;
use DBIx::Class::DeploymentHandler;
use Test::More;

DBICDHTest::test_bundle(DBIx::Class::DeploymentHandler);

done_testing;
