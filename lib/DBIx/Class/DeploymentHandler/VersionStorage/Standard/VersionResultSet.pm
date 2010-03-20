package DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResultSet;

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet';

use Try::Tiny;

sub version_storage_is_installed {
  my $self = shift;
  try { $self->next; 1} catch { undef }
}

sub database_version {
  my $self = shift;
  $self->search(undef, {
    order_by => { -desc => 'installed' },
    rows => 1
  })->get_column('version')->next;
}

1;
