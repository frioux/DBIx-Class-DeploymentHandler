package DBIx::Class::DeploymentHandler::HandlesDeploy;
use Moose::Role;

# ABSTRACT: Interface for deploy methods

requires 'prepare_deploy';
requires 'deploy';

requires 'prepare_resultsource_install';
requires 'install_resultsource';

requires 'prepare_upgrade';
requires 'upgrade_single_step';

requires 'prepare_downgrade';
requires 'downgrade_single_step';

1;

# vim: ts=2 sw=2 expandtab

__END__

=method prepare_deploy

 $dh->prepare_deploy

Generate the needed data files to install the schema to the database.

=method deploy

 $dh->deploy

Deploy the schema to the database.

=method prepare_resultsource_install

 $dh->prepare_resultsource_install($resultset->result_source)

Takes a L<DBIx::Class::ResultSource> and generates a single migration file to
create the resultsource's table.

=method install_resultsource

 $dh->prepare_resultsource_install($resultset->result_source);

Takes a L<DBIx::Class::ResultSource> and runs a single migration file to
deploy the resultsource's table.

=method prepare_upgrade

 $dh->prepare_upgrade(1, 2, [1, 2]);

Takes two versions and a version set.  This basically is supposed to generate
the needed C<SQL> to migrate up from the first version to the second version.
The version set uniquely identifies the migration.

=method prepare_downgrade

 $dh->prepare_downgrade(2, 1, [1, 2]);

Takes two versions and a version set.  This basically is supposed to generate
the needed C<SQL> to migrate down from the first version to the second version.
The version set uniquely identifies the migration and should match it's
respective upgrade version set.

=method upgrade_single_step

 my ($ddl, $sql) = @{$dh->upgrade_single_step($version_set)||[]}

Call a single upgrade migration.  Takes a version set as an argument.
Optionally return C<< [ $ddl, $upgrade_sql ] >> where C<$ddl> is the DDL for
that version of the schema and C<$upgrade_sql> is the SQL that was run to
upgrade the database.

=method downgrade_single_step

 $dh->downgrade_single_step($version_set);

Call a single downgrade migration.  Takes a version set as an argument.
Optionally return C<< [ $ddl, $upgrade_sql ] >> where C<$ddl> is the DDL for
that version of the schema and C<$upgrade_sql> is the SQL that was run to
upgrade the database.

=head1 KNOWN IMPLEMENTATIONS

=over

=item *

L<DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator>

=item *

L<DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::Deprecated>

=back

