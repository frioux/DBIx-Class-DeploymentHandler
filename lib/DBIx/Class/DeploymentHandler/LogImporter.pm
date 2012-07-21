package DBIx::Class::DeploymentHandler::LogImporter;

use warnings;
use strict;

use parent 'Log::Contextual';

use DBIx::Class::DeploymentHandler::Logger;

my $logger = DBIx::Class::DeploymentHandler::Logger->new({
   env_prefix => 'DBICDH'
});

sub arg_package_logger { $_[1] || $logger }

1;
