
#!perl

use Test::More;
use Test::Exception;

use lib 't/lib';
use DBICDHTest;
use_ok 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::Deprecated';

done_testing;
