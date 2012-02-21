package DBIx::Class::DeploymentHandler::MigrationSchema::FromCurrent;

use Moose;
with 'DBIx::Class::DeploymentHandler::HandlesMigrationSchema';

has schema => (is=>'ro', required=>1);

sub migration_schema { shift->schema }

1;

# vim: ts=2 sw=2 expandtab

__END__

=method migration_schema

  my $schema = $dh->migration_schema;

Provides a L<DBIx::Class::Schema> object that we can pass to the Perl deploy
scripts.  We just return whatever C<$schema> you passed when you instantiated
the L<DBIx::Class::DeploymentHandler> object.
