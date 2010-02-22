package DBIx::Class::DepolymentHandler::Component;

use strict;
use warnings;

use Carp 'carp';

sub connection  {
  my $self = shift;
  $self->next::method(@_);

  my $args = $_[3] || {};

  return if $args->{ignore_version} || $ENV{DBIC_NO_VERSION_CHECK};

  my $versions = $self->resultset('VersionResult');

  unless($versions->is_installed) {
	  carp "Your DB is currently unversioned. Please call upgrade on your schema to sync the DB.\n";
	  return 1;
  }

  my $pversion = $versions->db_version;

  return 1 if $pversion eq $self->schema_version;

  carp "Versions out of sync. This is " . $self->schema_version .
    ", your database contains version $pversion, please call upgrade on your Schema.\n";

  return $self;
}

1;
