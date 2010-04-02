package DBIx::Class::DeploymentHandler::HandlesVersionStorage;
use Moose::Role;

requires 'add_database_version';
requires 'database_version';
requires 'delete_database_version';
requires 'version_storage_is_installed';

1;


=head1 DESCRIPTION

Typically VersionStorages will be implemented with a simple
DBIx::Class::Result.  Take a look at the
L<two existing implementations|/KNOWN IMPLEMENTATIONS> for examples of what you
might want to do in your own storage.

=method add_database_version

 $dh->add_database_version({
   version     => '1.02',
   ddl         => $ddl # can be undef,
   upgrade_sql => $sql # can be undef,
 });

Store a new version into the version storage

=method database_version

 my $db_version = $version_storage->database_version;

=method delete_database_version

 $dh->delete_database_version({ version => '1.02' })

simply deletes given database version from the version storage

=method version_storage_is_installed

 warn q(I can't version this database!)
   unless $dh->version_storage_is_installed

return true iff the version storage is installed.

=head1 KNOWN IMPLEMENTATIONS

=over

=item *

L<DBIx::Class::DeploymentHandler::VersionStorage::Standard>

=item *

L<DBIx::Class::DeploymentHandler::VersionStorage::Deprecated>

=back

__END__

vim: ts=2 sw=2 expandtab
