package DBIx::Class::DeploymentHandler::VersionStorage::Standard;
use Moose;
use Method::Signatures::Simple;

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
);

has version_rs => (
  isa        => 'DBIx::Class::ResultSet',
  is         => 'ro',
  lazy_build => 1, # builder comes from another role...
                   # which is... probably not how we want it
  handles    => [qw( database_version version_storage_is_installed )],
);

with 'DBIx::Class::DeploymentHandler::HandlesVersionStorage';

sub _build_version_rs {
   $_[0]->schema->set_us_up_the_bomb;
   $_[0]->schema->resultset('__VERSION')
}

sub add_database_version { $_[0]->version_rs->create($_[1]) }

1;

__END__

vim: ts=2 sw=2 expandtab
