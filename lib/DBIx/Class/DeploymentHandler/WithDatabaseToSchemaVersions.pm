package DBIx::Class::DeploymentHandler::WithDatabaseToSchemaVersions;
use Moose::Role;

use DBIx::Class::DeploymentHandler::DatabaseToSchemaVersions;

use Carp 'carp';

has version_handler => (

# < mst> isa => 'DBIx::Class::DeploymentHandler::SqltDeployMethod',
# < mst> should be
# < mst> does => <some role>
# < mst> and that role should supply those methods
# < mst> then you can pass handles => <some role> as well

  isa => 'DBIx::Class::DeploymentHandler::DatabaseToSchemaVersions',
  is  => 'ro',
  lazy_build => 1,
  handles => [qw{ ordered_schema_versions }],
);

sub _build_version_handler {
  my $self = shift;
  DBIx::Class::DeploymentHandler::DatabaseToSchemaVersions->new({
    schema => $self->schema,
  });
}

1;

__END__

vim: ts=2 sw=2 expandtab
