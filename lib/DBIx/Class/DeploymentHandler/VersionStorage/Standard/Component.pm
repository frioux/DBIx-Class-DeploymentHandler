package DBIx::Class::DeploymentHandler::VersionStorage::Standard::Component;

use strict;
use warnings;

use Carp 'carp';
use DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResult;

sub set_us_up_the_bomb {
	my $self = shift;

	$self->register_class(
		__VERSION => 'DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResult'
	);
}

sub connection  {
  my $self = shift;
  $self->next::method(@_);

  $self->set_us_up_the_bomb;

  my $args = $_[3] || {};

  unless ( $args->{ignore_version} || $ENV{DBIC_NO_VERSION_CHECK}) {
	 my $versions = $self->resultset('__VERSION');

	 if (!$versions->is_installed) {
		 carp "Your DB is currently unversioned. Please call upgrade on your schema to sync the DB.\n";
	 } elsif ($versions->db_version ne $self->schema_version) {
		carp 'Versions out of sync. This is ' . $self->schema_version .
		  ', your database contains version ' . $versions->db_version . ", please call upgrade on your Schema.\n";
	 }
  }
  return $self;
}

1;
