package SH;

use strict;
use warnings;

use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::ScriptHelpers
   dbh => { -as => '_old_dbh' },
   schema_from_schema_loader => { -as => '_old_sfsl' };

use Sub::Exporter::Progressive -setup => {
   exports => [qw(dbh schema_from_schema_loader)],
};

our $DBH_RAN_OUTTER;
our $DBH_RAN_INNER;

sub dbh {
   my ($coderef) = @_;
   $DBH_RAN_OUTTER = 1;

   _old_dbh(sub {
      my ($dbh) = @_;

      $DBH_RAN_INNER = 1;

      $coderef->(@_);
   });
}

1;
