package DBIx::Class::DeploymentHandler::VersionStorage::Deprecated;
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
  builder    => '_build_version_rs',
  handles    => [qw( database_version version_storage_is_installed )],
);

with 'DBIx::Class::DeploymentHandler::HandlesVersionStorage';

use DBIx::Class::DeploymentHandler::VersionStorage::Deprecated::VersionResult;
sub _build_version_rs {
  $_[0]->schema->register_class(
    dbix_class_schema_versions =>
      'DBIx::Class::DeploymentHandler::VersionStorage::Deprecated::VersionResult'
  );
  $_[0]->schema->resultset('dbix_class_schema_versions')
}

sub add_database_version {
  # deprecated doesn't support ddl or upgrade_ddl
  $_[0]->version_rs->create({ version => $_[1]->{version} })
}

sub delete_database_version {
  $_[0]->version_rs->search({ version => $_[1]->{version}})->delete
}

__PACKAGE__->meta->make_immutable;

1;

# vim: ts=2 sw=2 expandtab

__END__

=head1 THIS SUCKS

Here's how to convert from that crufty old Deprecated VersionStorage to a shiny
new Standard VersionStorage:

 my $s  = My::Schema->connect(...);
 my $dh = DeploymentHandler({
   schema => $s,
 });

 $dh->prepare_version_storage_install;
 $dh->install_version_storage;

 my @versions = $s->{vschema}->resultset('Table')->search(undef, {
   order_by => 'installed',
 })->get_column('version')->all;

 $dh->version_storage->add_database_vesion({ version => $_ })
   for @versions;

