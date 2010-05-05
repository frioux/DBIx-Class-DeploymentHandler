package DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResultSet;

# ABSTRACT: Predefined searches to find what you want from the version storage

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet';

use Try::Tiny;

sub version_storage_is_installed {
  my $self = shift;
  try { $self->next; 1 } catch { undef }
}

sub database_version {
  my $self = shift;
  $self->search(undef, {
    order_by => { -desc => 'id' },
    rows => 1
  })->get_column('version')->next;
}

1;

# vim: ts=2 sw=2 expandtab

__END__

=method version_storage_is_installed

True if (!!!) the version storage has been installed

=method database_version

The version of the database
