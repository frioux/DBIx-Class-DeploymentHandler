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

  does => 'DBIx::Class::DeploymentHandler::HandlesVersioning',
  is  => 'ro',
  lazy_build => 1,
  handles => 'DBIx::Class::DeploymentHandler::HandlesVersioning',
);

sub _build_version_handler {
  my $self = shift;

  my $args = {
    schema => $self->schema,
  };

  $args->{to_version} = $self->to_version if $self->has_to_version;
  DBIx::Class::DeploymentHandler::DatabaseToSchemaVersions->new($args);
}

1;

__END__

vim: ts=2 sw=2 expandtab
