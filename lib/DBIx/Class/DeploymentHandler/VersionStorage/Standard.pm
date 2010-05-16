package DBIx::Class::DeploymentHandler::VersionStorage::Standard;
use Moose;

# ABSTRACT: Version storage that does the normal stuff

use Method::Signatures::Simple;
use DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResult;

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
);

has version_rs => (
  isa        => 'DBIx::Class::ResultSet',
  is         => 'ro',
  builder    => '_build_version_rs',
  handles    => [qw( database_version version_storage_is_installed )],
);

with 'DBIx::Class::DeploymentHandler::HandlesVersionStorage';

sub _build_version_rs {
  $_[0]->schema->register_class(
    __VERSION =>
      'DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResult'
  );
  $_[0]->schema->resultset('__VERSION')
}

sub add_database_version { $_[0]->version_rs->create($_[1]) }

sub delete_database_version {
  $_[0]->version_rs->search({ version => $_[1]->{version}})->delete
}

__PACKAGE__->meta->make_immutable;

1;

# vim: ts=2 sw=2 expandtab

__END__

