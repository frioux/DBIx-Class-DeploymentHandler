#!perl

use Test::More;
use lib 't/lib';

use_ok 'DBIx::Class::DeploymentHandler';
use_ok 'DBIx::Class::DeploymentHandler::VersionResult';
use_ok 'DBIx::Class::DeploymentHandler::VersionResultSet';
use_ok 'DBIx::Class::DeploymentHandler::Component';

done_testing;
