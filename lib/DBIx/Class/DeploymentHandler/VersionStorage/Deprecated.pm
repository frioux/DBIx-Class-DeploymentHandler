package DBIx::Class::DeploymentHandler::VersionStorage::Standard;
use Moose;
use Method::Signatures::Simple;

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
);

has version_rs => (
  isa        => 'DBIx::Class::ResultSet',
  is         => 'ro',
  lazy_build => 1,
  handles    => [qw( database_version version_storage_is_installed )],
);

with 'DBIx::Class::DeploymentHandler::HandlesVersionStorage';

sub _build_version_rs {
  $_[0]->schema->register_class(
    dbix_class_schema_versions =>
      'DBIx::Class::DeploymentHandler::VersionStorage::Deprecated::VersionResult'
  );
  $_[0]->schema->resultset('dbix_class_schema_versions')
}

sub add_database_version {
  # deprecated doesn't support ddl or upgrade_ddl
  $_[0]->version_rs->create({ version => $_[1]->{version} })
}

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
