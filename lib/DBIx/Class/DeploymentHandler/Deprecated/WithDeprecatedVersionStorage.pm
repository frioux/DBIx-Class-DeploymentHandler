package DBIx::Class::DeploymentHandler::Deprecated::WithDeprecatedVersionStorage;
use Moose::Role;

use DBIx::Class::DeploymentHandler::VersionStorage::Deprecated;

has version_storage => (
  does => 'DBIx::Class::DeploymentHandler::HandlesVersionStorage',
  is  => 'ro',
  lazy_build => 1,
  handles =>  'DBIx::Class::DeploymentHandler::HandlesVersionStorage',
);

sub _build_version_storage {
  DBIx::Class::DeploymentHandler::VersionStorage::Deprecated
    ->new({ schema => $_[0]->schema });
}

1;

__END__

vim: ts=2 sw=2 expandtab
