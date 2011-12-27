package DBIx::Class::DeploymentHandler::ProvideSchema::SchemaLoader;

use Moose;
use DBIx::Class::Schema::Loader;

with 'DBIx::Class::DeploymentHandler::HandlesProvideSchema';

has schema => (is=>'ro', required=>1);

my %opts = (
  naming => { ALL => 'v7'},
  use_namespaces => 1,
  debug => $ENV{DBIC_DEPLOYMENTHANDLER_DEBUG}||0);

my $cnt = 0;

sub schema_for_run_files {
  my $schema = shift->schema->clone;
  my $name = ref($schema) . $cnt++;
  DBIx::Class::Schema::Loader::make_schema_at
    $name, \%opts, [ sub {$schema->storage->dbh} ];
}

1;

# vim: ts=2 sw=2 expandtab

__END__

=method schema_for_run_files

  my $schema = $dh->schema_for_run_files;

Provides a L<DBIx::Class::Schema> object that we can pass to the Perl deploy
scripts.  We reverse engineer a C<$schema> from whatever is currently deployed
to the database using L<DBIx::Class::Schema::Loader>
