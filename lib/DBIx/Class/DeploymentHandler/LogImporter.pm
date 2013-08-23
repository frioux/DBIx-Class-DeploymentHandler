package DBIx::Class::DeploymentHandler::LogImporter;

use warnings;
use strict;

use parent 'Log::Contextual';

use DBIx::Class::DeploymentHandler::LogRouter;

{
   my $router;
   sub router { $router ||= DBIx::Class::DeploymentHandler::LogRouter->new }
}

1;
