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
  lazy_build => 1,
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

sub add_database_version { $_[0]->version_rs->create($_[1]) }

sub delete_database_version {
  $_[0]->version_rs->search({ version => $_[1]->{version}})->delete
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 THIS SUCKS

You started your project and weren't using DBICDH?  FOOL!  Lucky for you I had
you in mind when I wrote this doc <3

First off, you'll want to just install the version_storage:

 my $s = My::Schema->connect(...);
 my $dh = DeployHandler({ schema => $s });

 $dh->prepare_version_storage_install;
 $dh->install_version_storage;

Then, bump your schema version, and you can use DBICDH like normal!

vim: ts=2 sw=2 expandtab
