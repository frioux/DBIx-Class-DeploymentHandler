package DBIx::Class::DeploymentHandler::Deprecated;

use Moose;
use Moose::Util 'apply_all_roles';

extends 'DBIx::Class::DeploymentHandler::Dad';
with 'DBIx::Class::DeploymentHandler::Deprecated::WithDeprecatedSqltDeployMethod',
     'DBIx::Class::DeploymentHandler::Deprecated::WithDeprecatedVersionStorage';

sub BUILD {
  my $self = shift;

  if ($self->schema->can('ordered_versions') && $self->schema->ordered_versions) {
    apply_all_roles(
      $self,
      'DBIx::Class::DeploymentHandler::WithExplicitVersions'
    );
  } else {
    apply_all_roles(
      $self,
      'DBIx::Class::DeploymentHandler::WithDatabaseToSchemaVersions'
    );
  }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
