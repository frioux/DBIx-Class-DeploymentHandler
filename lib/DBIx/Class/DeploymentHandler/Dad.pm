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

=head2 deploy

See L<DBIx::Class::DeploymentHandler::HandlesDeploy/deploy>.

=head2 version_storage_is_installed

See L<DBIx::Class::DeploymentHandler::HandlesVersionStorage/version_storage_is_installed>.

=head2 add_database_version

See L<DBIx::Class::DeploymentHandler::HandlesVersionStorage/add_database_version>.

=head2 delete_database_version

See L<DBIx::Class::DeploymentHandler::HandlesVersionStorage/delete_database_version>.

=head2 next_version_set

See L<DBIx::Class::DeploymentHandler::HandlesVersioning/next_version_set>.

=head2 previous_version_set

See L<DBIx::Class::DeploymentHandler::HandlesVersioning/previous_version_set>.

=head2 upgrade_single_step

See L<DBIx::Class::DeploymentHandler::HandlesDeploy/upgrade_single_step>.

=head2 downgrade_single_step

See L<DBIx::Class::DeploymentHandler::HandlesDeploy/downgrade_single_step>.

=head1 ORTHODOX METHODS

These methods are not actually B<required> as things will probably still work
if you don't implement them, but if you want your subclass to get along with
other subclasses (or more likely, tools made to use another subclass), you
should probably implement these too, even if they are no-ops.

=head2 database_version

see L<DBIx::Class::DeploymentHandler::HandlesVersionStorage/database_version>

=head2 prepare_install

see L<DBIx::Class::DeploymentHandler::HandlesDeploy/prepare_install>

=head2 prepare_resultsource_install

see L<DBIx::Class::DeploymentHandler::HandlesDeploy/prepare_resultsouce_install>

=head2 install_resultsource

see L<DBIx::Class::DeploymentHandler::HandlesDeploy/install_resultsource>

=head2 prepare_upgrade

see L<DBIx::Class::DeploymentHandler::HandlesDeploy/prepare_upgrade>

=head2 prepare_downgrade

see L<DBIx::Class::DeploymentHandler::HandlesDeploy/prepare_downgrade>

=back

=head2 SUBCLASSING

All of the methods mentioned in L</METHODS THAT ARE REQUIRED IN SUBCLASSES> and
L</ORTHODOX METHODS> can be implemented in any fashion you choose.  In the
spirit of code reuse I have used roles to implement them in my two subclasses,
L<DBIx::Class::DeploymentHandler> and
L<DBIx::Class::DeploymentHandler::Deprecated>, but you are free to implement
them entirely in a subclass if you so choose to.

For in-depth documentation on how methods are supposed to work, see the roles
L<DBIx::Class::DeploymentHandler::HandlesDeploy>,
L<DBIx::Class::DeploymentHandler::HandlesVersioning>, and
L<DBIx::Class::DeploymentHandler::HandlesVersionStorage>.

__END__

vim: ts=2 sw=2 expandtab
