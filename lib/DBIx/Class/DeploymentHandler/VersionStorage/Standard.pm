package DBIx::Class::DeploymentHandler::VersionStorage::Standard;
use Moose;
use Log::Contextual::WarnLogger;
use Log::Contextual ':log', -default_logger => Log::Contextual::WarnLogger->new({
  env_prefix => 'DBICDH'
});

# ABSTRACT: Version storage that does the normal stuff

use Method::Signatures::Simple;
use DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResult;

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
);

has version_rs => (
  isa        => 'DBIx::Class::ResultSet',
  is         => 'ro',
  builder    => '_build_version_rs',
  handles    => [qw( database_version version_storage_is_installed )],
);

with 'DBIx::Class::DeploymentHandler::HandlesVersionStorage';

sub _build_version_rs {
  $_[0]->schema->register_class(
    __VERSION =>
      'DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResult'
  );
  $_[0]->schema->resultset('__VERSION')
}

sub add_database_version {
  my $version = $_[1]->{version};
  log_debug { "[DBICDH] Adding database version $version" };
  $_[0]->version_rs->create($_[1])
}

sub delete_database_version {
  my $version = $_[1]->{version};
  log_debug { "[DBICDH] Deleting database version $version" };
  $_[0]->version_rs->search({ version => $version})->delete
}

__PACKAGE__->meta->make_immutable;

1;

# vim: ts=2 sw=2 expandtab

__END__

