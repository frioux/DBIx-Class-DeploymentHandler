package DBIx::Class::DeploymentHandler;

use Moose;
use Method::Signatures::Simple;
require DBIx::Class::Schema;    # loaded for type constraint
require DBIx::Class::Storage;   # loaded for type constraint
require DBIx::Class::ResultSet; # loaded for type constraint
use Carp::Clan '^DBIx::Class::DeploymentHandler';

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
  handles => [qw{schema_version}],
);

has upgrade_directory => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
  default  => 'sql',
);

has backup_directory => (
  isa => 'Str',
  is  => 'ro',
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

has _filedata => (
  isa => 'Str',
  is  => 'rw',
);

has do_backup => (
  isa     => 'Bool',
  is      => 'ro',
  default => undef,
);

has do_diff_on_init => (
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

method _build_version_rs { $self->schema->resultset('VersionResult') }

method backup { $self->storage->backup($self->backup_directory) }

method install($new_version) {
  carp 'Install not possible as versions table already exists in database'
    unless $self->is_installed;

  $new_version ||= $self->schema_version;

  if ($new_version) {
    $self->schema->deploy;

    $self->version_rs->create({
      version     => $new_version,
      # ddl         => $ddl,
      # upgrade_sql => $upgrade_sql,
    });
  }
}

method create_upgrade_path { }

method ordered_schema_versions { }

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

method upgrade_single_step($db_version, $target_version) {
  if ($db_version eq $target_version) {
    # croak?
    carp "Upgrade not necessary\n";
    return;
  }

  my $upgrade_file = $self->ddl_filename(
    $self->storage->sqlt_type,
    $target_version,
    $self->upgrade_directory,
    $db_version,
  );

  $self->create_upgrade_path({ upgrade_file => $upgrade_file });

  unless (-f $upgrade_file) {
    # croak?
    carp "Upgrade not possible, no upgrade file found ($upgrade_file), please create one\n";
    return;
  }

  carp "DB version ($db_version) is lower than the schema version (".$self->schema_version."). Attempting upgrade.\n";

  $self->_filedata($self->_read_sql_file($upgrade_file)); # I don't like this --fREW 2010-02-22
  $self->backup if $self->do_backup;
  $self->schema->txn_do(sub { $self->do_upgrade });

  $self->version_rs->create({
    version     => $target_version,
    # ddl         => $ddl,
    # upgrade_sql => $upgrade_sql,
  });
}

method do_upgrade { $self->run_upgrade(qr/.*?/) }

method run_upgrade($stm) {
  return unless $self->_filedata;
  my @statements = grep { $_ =~ $stm } @{$self->_filedata};

  for (@statements) {
    $self->storage->debugobj->query_start($_) if $self->storage->debug;
    $self->apply_statement($_);
    $self->storage->debugobj->query_end($_) if $self->storage->debug;
  }
}

method apply_statement($statement) {
  # croak?
  $self->storage->dbh->do($_) or carp "SQL was: $_"
}

sub _create_db_to_schema_diff {
  my $self = shift;

  my %driver_to_db_map = (
    'mysql' => 'MySQL'
  );

  my $db = $driver_to_db_map{$self->storage->dbh->{Driver}{Name}};
  unless ($db) {
    # croak?
    print "Sorry, this is an unsupported DB\n";
    return;
  }

  $self->throw_exception($self->storage->_sqlt_version_error)
    unless $self->storage->_sqlt_version_ok;

  my $db_tr = SQL::Translator->new({
    add_drop_table => 1,
    parser         => 'DBI',
    parser_args    => { dbh  => $self->storage->dbh },
    producer       => $db,
  });

  my $dbic_tr = SQL::Translator->new({
    parser   => 'SQL::Translator::Parser::DBIx::Class',
    data     => $self,
    producer => $db,
  });

  $db_tr->schema->name('db_schema');
  $dbic_tr->schema->name('dbic_schema');

  # is this really necessary?
  foreach my $tr ($db_tr, $dbic_tr) {
    my $data = $tr->data;
    $tr->parser->($tr, $$data);
  }

  my $diff = SQL::Translator::Diff::schema_diff(
    $db_tr->schema,   $db,
    $dbic_tr->schema, $db, {
      ignore_constraint_names => 1,
      ignore_index_names      => 1,
      caseopt                 => 1,
    }
  );

  my $filename = $self->ddl_filename(
    $db,
    $self->schema_version,
    $self->upgrade_directory,
    'PRE',
  );

  open my $file, '>', $filename
    or $self->throw_exception("Can't open $filename for writing ($!)");
  print {$file} $diff;
  close $file;

  carp "WARNING: There may be differences between your DB and your DBIC schema.\n" .
       "Please review and if necessary run the SQL in $filename to sync your DB.\n";
}

method _read_sql_file($file) {
  return unless $file;

  open my $fh, '<', $file or carp("Can't open upgrade file, $file ($!)");
  my @data = split /\n/, join '', <$fh>;
  close $fh;

  @data = grep {
    $_ &&
    !/^--/ &&
    !/^(BEGIN|BEGIN TRANSACTION|COMMIT)/m
  } split /;/,
    join '', @data;

  return \@data;
}

1;

__END__

vim: ts=2,sw=2,expandtab
