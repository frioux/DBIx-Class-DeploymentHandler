package DBIx::Class::DeploymentHandler::HandlesVersionStorage;
use Moose::Role;

requires 'database_version';
requires 'add_database_version';
requires 'delete_database_version';
requires 'version_storage_is_installed';

1;

__END__

=method database_version

 my $db_version = $version_storage->database_version;

=method add_database_version

 $version_storage->add_database_version({
   version     => '1.2002',
   ddl         => $ddl,     # optional
   upgrade_sql => undef,    # optional
 })

=method delete_database_version

 $version_storage->delete_database_version({ version => '1.2002' })

=method version_storage_is_installed

 if ($verson_storage->version_storage_is_installed) {
   say q(you're golden!)
 }

vim: ts=2 sw=2 expandtab
