package DBIx::Class::DeploymentHandler::ProvideSchema::SQL::FromCurrent;

use Moose;
with 'DBIx::Class::DeploymentHandler::HandlesProvideSchema';

has schema => (is=>'ro', required=>1);

sub schema_for_run_files { shift->schema }

1;

# vim: ts=2 sw=2 expandtab

__END__

=method schema_for_run_files

  my $schema = $dh->schema_for_run_files;

Provides a L<DBIx::Class::Schema> object that we can pass to the Perl deploy
scripts.  We just return whatever C<$schema> you passed when you instantiated
the L<DBIx::Class::DeploymentHandler> object.
