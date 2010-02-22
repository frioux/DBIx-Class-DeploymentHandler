package DBIx::Class::DeploymentHandler::VersionResultSet;

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet';

use Try::Tiny;

sub is_installed {
  my $self = shift;
  try { $self->next; 1} catch { undef }
}

sub db_version {
  my $self = shift;
  $self->search(undef, {
    order_by => { -desc => 'installed' },
    rows => 1
  })->get_column('version')->next || 0;
}

1;
