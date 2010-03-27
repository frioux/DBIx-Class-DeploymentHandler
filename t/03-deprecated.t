#!perl

use lib 't/lib';
use DBICDHTest;
use DBIx::Class::DeploymentHandler::Deprecated;
use Test::More;

DBICDHTest::test_bundle(DBIx::Class::DeploymentHandler::Deprecated);

done_testing;
