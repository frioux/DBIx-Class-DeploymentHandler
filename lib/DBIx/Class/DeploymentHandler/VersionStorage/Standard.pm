package DBIx::Class::DeploymentHandler::VersionStorage::Standard;

use Moose::Role;
use DBIx::Class::DeploymentHandler::LogImporter ':log';

# ABSTRACT: Version storage that does the normal stuff

use DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResult;

has version_rs => (
  isa        => 'DBIx::Class::ResultSet',
  is         => 'ro',
  lazy       => 1,
  builder    => '_build_version_rs',
  handles    => [qw( database_version version_storage_is_installed )],
);

# handles methods don't make it in time?
sub database_version { $_[0]->version_rs->database_version }
sub version_storage_is_installed { $_[0]->version_rs->version_storage_is_installed }

with 'DBIx::Class::DeploymentHandler::HandlesVersionStorage';

sub _build_version_rs {
  $_[0]->schema->register_class(
    __VERSION =>
      'DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResult'
  );
  $_[0]->schema->resultset('__VERSION')
}

sub add_database_version {
  my $version = $_[1]->{version};
  log_debug { "Adding database version $version" };
  $_[0]->version_rs->create($_[1])
}

sub delete_database_version {
  my $version = $_[1]->{version};
  log_debug { "Deleting database version $version" };
  $_[0]->version_rs->search({ version => $version})->delete
}


1;

# vim: ts=2 sw=2 expandtab

__END__

=head1 SEE ALSO

This class is an implementation of
L<DBIx::Class::DeploymentHandler::HandlesVersionStorage>.  Pretty much all the
documentation is there.
