package DBIx::Class::DeploymentHandler::HandlesMigrationSchema;
use Moose::Role;

# ABSTRACT: Interface for providing a $schema to the deployment scripts

requires 'migration_schema';

1;

# vim: ts=2 sw=2 expandtab

__END__

=method migration_schema

  my $schema = $dh->migration_schema;

Provides a L<DBIx::Class::Schema> object that we can pass to the Perl deploy
scripts.

=head1 KNOWN IMPLEMENTATIONS

=over

=item *

L<DBIx::Class::DeploymentHandler::MigrationSchema::FromCurrent>

=item *

L<DBIx::Class::DeploymentHandler::MigrationSchema::SQL::SchemaLoader>

=back

