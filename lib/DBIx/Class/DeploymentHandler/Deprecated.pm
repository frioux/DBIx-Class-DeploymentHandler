package DBIx::Class::DeploymentHandler::Deprecated;

# ABSTRACT: (DEPRECATED) Use this if you are stuck in the past

use Moose;
use Moose::Util 'apply_all_roles';

extends 'DBIx::Class::DeploymentHandler::Dad';
# a single with would be better, but we can't do that
# see: http://rt.cpan.org/Public/Bug/Display.html?id=46347
with 'DBIx::Class::DeploymentHandler::Deprecated::WithDeprecatedSqltDeployMethod',
     'DBIx::Class::DeploymentHandler::Deprecated::WithDeprecatedVersionStorage';
with 'DBIx::Class::DeploymentHandler::WithReasonableDefaults';

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

# vim: ts=2 sw=2 expandtab

__END__


