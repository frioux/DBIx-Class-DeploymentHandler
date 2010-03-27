package DBIx::Class::DeploymentHandler;

use Moose;

extends 'DBIx::Class::DeploymentHandler::Dad';
with 'DBIx::Class::DeploymentHandler::WithSqltDeployMethod',
     'DBIx::Class::DeploymentHandler::WithDatabaseToSchemaVersions',
     'DBIx::Class::DeploymentHandler::WithStandardVersionStorage';

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
