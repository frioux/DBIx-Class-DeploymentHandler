package DBIx::Class::DeploymentHandler::MigrationSchema::SchemaLoader;

use Moose;
use DBIx::Class::Schema::Loader;

with 'DBIx::Class::DeploymentHandler::HandlesMigrationSchema';

has schema => (is=>'ro', required=>1);

my %opts = (
  naming => { ALL => 'v7'},
  use_namespaces => 1,
  debug => $ENV{DBIC_DEPLOYMENTHANDLER_DEBUG}||0);

my $cnt = 0;

sub migration_schema {
  my $schema = shift->schema->clone;
  my $name = ref($schema) . $cnt++;
  DBIx::Class::Schema::Loader::make_schema_at
    $name, \%opts, [ sub {$schema->storage->dbh} ];
}

1;

# vim: ts=2 sw=2 expandtab

__END__

=method migration_schema

  my $schema = $dh->migration_schema;

Provides a L<DBIx::Class::Schema> object that we can pass to the Perl deploy
scripts.  We reverse engineer a C<$schema> from whatever is currently deployed
to the database using L<DBIx::Class::Schema::Loader>
