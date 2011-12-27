package DBIx::Class::DeploymentHandler::HandlesProvideSchema;
use Moose::Role;

# ABSTRACT: Interface for providing a $schema to the deployment scripts

requires 'migration_schema';

1;

# vim: ts=2 sw=2 expandtab

__END__

=method schema_for_run_files

  my $schema = $dh->schema_for_run_files;

Provides a L<DBIx::Class::Schema> object that we can pass to the Perl deploy
scripts.

=head1 KNOWN IMPLEMENTATIONS

=over

=item *

L<DBIx::Class::DeploymentHandler::ProvideSchema::FromCurrent>

=item *

L<DBIx::Class::DeploymentHandler::ProvideSchema::SQL::SchemaLoader>

=back

