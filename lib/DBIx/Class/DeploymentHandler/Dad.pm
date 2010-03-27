package DBIx::Class::DeploymentHandler::Dad;

use Moose;
use Method::Signatures::Simple;
use DBIx::Class::DeploymentHandler::Types;
require DBIx::Class::Schema;    # loaded for type constraint
require DBIx::Class::ResultSet; # loaded for type constraint
use Carp::Clan '^DBIx::Class::DeploymentHandler';

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
  handles => ['schema_version'],
);

has upgrade_directory => ( # configuration
  isa      => 'Str',
  is       => 'ro',
  required => 1,
  default  => 'sql',
);

has backup_directory => ( # configuration
  isa => 'Str',
  is  => 'ro',
  predicate  => 'has_backup_directory',
);

has to_version => ( # configuration
  is         => 'ro',
  lazy_build => 1,
);

sub _build_to_version { $_[0]->schema->schema_version }

has databases => ( # configuration
  coerce  => 1,
  isa     => 'DBIx::Class::DeploymentHandler::Databases',
  is      => 'ro',
  default => sub { [qw( MySQL SQLite PostgreSQL )] },
);

has sqltargs => ( # configuration
  isa => 'HashRef',
  is  => 'ro',
  default => sub { {} },
);

method install {
  croak 'Install not possible as versions table already exists in database'
    if $self->version_storage_is_installed;

  my $ddl = $self->_deploy;

  $self->version_storage->add_database_version({
    version     => $self->to_version,
    ddl         => $ddl,
  });
}

sub upgrade {
  my $self = shift;
  while ( my $version_list = $self->next_version_set ) {
    my ($ddl, $upgrade_sql) = @{$self->_upgrade_single_step($version_list)||[]};

    $self->add_database_version({
      version     => $version_list->[-1],
      ddl         => $ddl,
      upgrade_sql => $upgrade_sql,
    });
  }
}

method backup { $self->storage->backup($self->backup_directory) }

method deploy_version_storage {
  $self->
}

__PACKAGE__->meta->make_immutable;

1;

=pod

=attr schema

=attr upgrade_directory

=attr backup_directory

=attr to_version

=attr databases

=method install

=method upgrade

=method backup

__END__

vim: ts=2 sw=2 expandtab
