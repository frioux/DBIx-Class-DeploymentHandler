package DBIx::Class::DeploymentHandler;

use Moose;
use Method::Signatures::Simple;
require DBIx::Class::Schema;    # loaded for type constraint
require DBIx::Class::Storage;   # loaded for type constraint
require DBIx::Class::ResultSet; # loaded for type constraint
use Carp::Clan '^DBIx::Class::DeploymentHandler';
use SQL::Translator;
require SQL::Translator::Diff;
use Try::Tiny;

with 'DBIx::Class::DeploymentHandler::WithSqltDeployMethod';

BEGIN {
  use Moose::Util::TypeConstraints;
  subtype 'DBIx::Class::DeploymentHandler::Databases'
    => as 'ArrayRef[Str]';

  coerce 'DBIx::Class::DeploymentHandler::Databases'
    => from 'Str'
    => via { [$_] };
  no Moose::Util::TypeConstraints;
}

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
  handles => [qw( ddl_filename schema_version )],
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

has storage => (
  isa        => 'DBIx::Class::Storage',
  is         => 'ro',
  lazy_build => 1,
);

method _build_storage {
  my $s = $self->schema->storage;
  $s->_determine_driver;
  $s
}

has do_backup => ( # configuration
  isa     => 'Bool',
  is      => 'ro',
  default => undef,
);

has version_rs => (
  isa        => 'DBIx::Class::ResultSet',
  is         => 'ro',
  lazy_build => 1,
  handles    => [qw( is_installed db_version )],
);

method _build_version_rs {
   $self->schema->set_us_up_the_bomb;
   $self->schema->resultset('__VERSION')
}

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

method deploy {
  my $storage  = $self->storage;

  my $deploy = sub {
    my $line = shift;
    # the \nCOMMIT below is entirely to make the tests quieter,
    # there is surely a better way to fix it (/m breaks everything)
    return if(!$line || $line =~ /^(--|BEGIN TRANSACTION|\nCOMMIT|\s+$)/);
    $storage->_query_start($line);
    try {
      # do a dbh_do cycle here, as we need some error checking in
      # place (even though we will ignore errors)
      $storage->dbh_do (sub { $_[1]->do($line) });
    }
    catch {
      carp "$_ (running '${line}')"
    }
    $storage->_query_end($line);
  };
  my @statements = $self->deployment_statements;
  if (@statements > 1) {
    foreach my $statement (@statements) {
      $deploy->( $statement );
    }
  }
  elsif (@statements == 1) {
    foreach my $line ( split(";\n", $statements[0])) {
      $deploy->( $line );
    }
  }
}

method install($new_version) {
  carp 'Install not possible as versions table already exists in database'
    if $self->is_installed;

  $new_version ||= $self->schema_version;

  if ($new_version) {
    $self->deploy;

    $self->version_rs->create({
      version     => $new_version,
      # ddl         => $ddl,
      # upgrade_sql => $upgrade_sql,
    });
  }
}

method ordered_schema_versions { undef }

method upgrade {
  my $db_version     = $self->db_version;
  my $schema_version = $self->schema_version;

  unless ($db_version) {
    # croak?
    carp 'Upgrade not possible as database is unversioned. Please call install first.';
    return;
  }

  if ( $db_version eq $schema_version ) {
    # croak?
    carp "Upgrade not necessary\n";
    return;
  }

  my @version_list = $self->ordered_schema_versions ||
    ( $db_version, $schema_version );

  # remove all versions in list above the required version
  while ( @version_list && ( $version_list[-1] ne $schema_version ) ) {
    pop @version_list;
  }

  # remove all versions in list below the current version
  while ( @version_list && ( $version_list[0] ne $db_version ) ) {
    shift @version_list;
  }

  # check we have an appropriate list of versions
  die if @version_list < 2;

  # do sets of upgrade
  while ( @version_list >= 2 ) {
    $self->upgrade_single_step( $version_list[0], $version_list[1] );
    shift @version_list;
  }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
