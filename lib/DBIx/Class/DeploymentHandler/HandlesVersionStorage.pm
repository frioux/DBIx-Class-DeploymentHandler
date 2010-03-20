package DBIx::Class::DeploymentHandler::HandlesVersionStorage;
use Moose::Role;

requires 'database_version';
requires 'add_database_version';
requires 'version_storage_is_installed';

1;

__END__

vim: ts=2 sw=2 expandtab
