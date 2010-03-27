package DBIx::Class::DeploymentHandler;

use Moose;

extends 'DBIx::Class::DeploymentHandler::Dad';
# a single with would be better, but we can't do that
# see: http://rt.cpan.org/Public/Bug/Display.html?id=46347
with 'DBIx::Class::DeploymentHandler::WithSqltDeployMethod',
     'DBIx::Class::DeploymentHandler::WithDatabaseToSchemaVersions',
     'DBIx::Class::DeploymentHandler::WithStandardVersionStorage';
with 'DBIx::Class::DeploymentHandler::WithReasonableDefaults';

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
