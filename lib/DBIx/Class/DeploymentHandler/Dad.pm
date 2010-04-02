package DBIx::Class::DeploymentHandler::Dad;

use Moose;
use Method::Signatures::Simple;
require DBIx::Class::Schema;    # loaded for type constraint
use Carp::Clan '^DBIx::Class::DeploymentHandler';

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
  handles => ['schema_version'],
);

has backup_directory => (
  isa => 'Str',
  is  => 'ro',
  predicate  => 'has_backup_directory',
);

has to_version => (
  is         => 'ro',
  lazy_build => 1,
);

sub _build_to_version { $_[0]->schema->schema_version }

method install {
  croak 'Install not possible as versions table already exists in database'
    if $self->version_storage_is_installed;

  my $ddl = $self->deploy;

  $self->add_database_version({
    version     => $self->to_version,
    ddl         => $ddl,
  });
}

sub upgrade {
  my $self = shift;
  while ( my $version_list = $self->next_version_set ) {
    my ($ddl, $upgrade_sql) = @{$self->upgrade_single_step($version_list)||[]};

    $self->add_database_version({
      version     => $version_list->[-1],
      ddl         => $ddl,
      upgrade_sql => $upgrade_sql,
    });
  }
}

sub downgrade {
  my $self = shift;
  while ( my $version_list = $self->previous_version_set ) {
    $self->downgrade_single_step($version_list);

    # do we just delete a row here?  I think so but not sure
    $self->delete_database_version({ version => $version_list->[-1] });
  }
}

method backup { $self->storage->backup($self->backup_directory) }

__PACKAGE__->meta->make_immutable;

1;

=pod

=attr schema

The L<DBIx::Class::Schema> (B<required>) that is used to talk to the database
and generate the DDL.

=attr backup_directory

The directory that backups are stored in

=attr to_version

The version (defaults to schema's version) to migrate the database to

=method install

 $dh->install

Deploys the current schema into the database.  Populates C<version_storage> with
C<version> and C<ddl>.

B<Note>: you typically need to call C<< $dh->prepare_install >> before you call
this method.

B<Note>: you cannot install on top of an already installed database

=method upgrade

 $dh->upgrade

Upgrades the database one step at a time till L</next_version_set>
returns C<undef>.  Each upgrade step will add a C<version>, C<ddl>, and
C<upgrade_sql> to the version storage (if C<ddl> and/or C<upgrade_sql> are
returned from L</upgrade_single_step>.

=method downgrade

 $dh->downgrade

Downgrades the database one step at a time till L</previous_version_set>
returns C<undef>.  Each downgrade step will delete a C<version>from the
version storage.

=method backup

 $dh->backup

Simply calls backup on the C<< $schema->storage >>, passing in
C<< $self->backup_directory >> as an argument.  Please test yourself before
assuming it will work.

=head1 METHODS THAT ARE REQUIRED IN SUBCLASSES

=head2 version_storage_is_installed

 warn q(I can't version this database!)
   unless $dh->version_storage_is_installed

return true iff the version storage is installed.

=head2 deploy

 $dh->deploy

Deploy the schema to the database.

=head2 add_database_version

 $dh->add_database_version({
   version     => '1.02',
   ddl         => $ddl # can be undef,
   upgrade_sql => $sql # can be undef,
 });

Store a new version into the version storage

=head2 delete_database_version

 $dh->delete_database_version({ version => '1.02' })

simply deletes given database version from the version storage

=head2 next_version_set

 print 'versions to install: ';
 while (my $vs = $dh->next_version_set) {
   print join q(, ), @{$vs}
 }
 print qq(\n);

return an arrayref describing each version that needs to be
installed to upgrade to C<< $dh->to_version >>.

=head2 previous_version_set

 print 'versions to uninstall: ';
 while (my $vs = $dh->previous_version_set) {
   print join q(, ), @{$vs}
 }
 print qq(\n);

return an arrayref describing each version that needs to be
"installed" to downgrade to C<< $dh->to_version >>.

=head2 upgrade_single_step

 my ($ddl, $sql) = @{$dh->upgrade_single_step($version_set)||[]}

call a single upgrade migration.  Takes an arrayref describing the version to
upgrade to.  Optionally return an arrayref containing C<$ddl> describing
version installed and C<$sql> used to get to that version.

=head2 downgrade_single_step

 $dh->upgrade_single_step($version_set);

call a single downgrade migration.  Takes an arrayref describing the version to
downgrade to.

__END__

vim: ts=2 sw=2 expandtab
