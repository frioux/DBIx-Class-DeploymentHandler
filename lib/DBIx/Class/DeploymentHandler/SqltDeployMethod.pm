package DBIx::Class::DeploymentHandler::SqltDeployMethod;
use Moose;
use Method::Signatures::Simple;
use Try::Tiny;
use SQL::Translator;
require SQL::Translator::Diff;
require DBIx::Class::Storage;   # loaded for type constraint

use Carp 'carp';

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

has backup_directory => (
  isa => 'Str',
  is  => 'ro',
);

has do_backup => (
  isa     => 'Bool',
  is      => 'ro',
  default => undef,
);

has sqltargs => (
  isa => 'HashRef',
  is  => 'ro',
  default => sub { {} },
);
has upgrade_directory => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
  default  => 'sql',
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

has databases => (
  coerce  => 1,
  isa     => 'DBIx::Class::DeploymentHandler::Databases',
  is      => 'ro',
  default => sub { [qw( MySQL SQLite PostgreSQL )] },
);

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
  handles => [qw( schema_version )],
);

has _filedata => (
  isa => 'ArrayRef[Str]',
  is  => 'rw',
);

method _ddl_filename($type, $versions, $dir) {
  my $filename = ref $self->schema;
  $filename =~ s/::/-/g;

  $filename = File::Spec->catfile(
    $dir, "$filename-" . join( q(-), @{$versions} ) . "-$type.sql"
  );

  return $filename;
}

method _deployment_statements {
  my $dir      = $self->upgrade_directory;
  my $schema   = $self->schema;
  my $type     = $self->storage->sqlt_type;
  my $sqltargs = $self->sqltargs;
  my $version  = $self->schema_version || '1.x';

  my $filename = $self->_ddl_filename($type, [ $version ], $dir);
  if(-f $filename) {
      my $file;
      open $file, q(<), $filename
        or carp "Can't open $filename ($!)";
      my @rows = <$file>;
      close $file;
      return join '', @rows;
  }

  # sources needs to be a parser arg, but for simplicty allow at top level
  # coming in
  $sqltargs->{parser_args}{sources} = delete $sqltargs->{sources}
      if exists $sqltargs->{sources};

  my $tr = SQL::Translator->new(
    producer => "SQL::Translator::Producer::${type}",
    %$sqltargs,
    parser => 'SQL::Translator::Parser::DBIx::Class',
    data => $schema,
  );

  my @ret;
  my $wa = wantarray;
  if ($wa) {
    @ret = $tr->translate;
  }
  else {
    $ret[0] = $tr->translate;
  }

  $schema->throw_exception( 'Unable to produce deployment statements: ' . $tr->error)
    unless (@ret && defined $ret[0]);

  return $wa ? @ret : $ret[0];
}

method _deploy {
  my $storage  = $self->storage;

  my $deploy = sub {
    my $line = shift;
    return if(!$line || $line =~ /^--|^BEGIN TRANSACTION|^COMMIT|^\s+$/);
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
  my @statements = $self->_deployment_statements();
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

method prepare_install {
  my $schema    = $self->schema;
  my $databases = $self->databases;
  my $dir       = $self->upgrade_directory;
  my $sqltargs  = $self->sqltargs;
  unless( -d $dir ) {
    carp "Upgrade directory $dir does not exist, using ./\n";
    $dir = "./";
  }

  my $version = $schema->schema_version || '1.x';
  my $schema_version = $schema->schema_version || '1.x';
  $version ||= $schema_version;

  $sqltargs = {
    add_drop_table => 1,
    ignore_constraint_names => 1,
    ignore_index_names => 1,
    %{$sqltargs || {}}
  };

  my $sqlt = SQL::Translator->new( $sqltargs );

  $sqlt->parser('SQL::Translator::Parser::DBIx::Class');
  my $sqlt_schema = $sqlt->translate({ data => $schema })
    or $self->throw_exception ($sqlt->error);

  foreach my $db (@$databases) {
    $sqlt->reset;
    $sqlt->{schema} = $sqlt_schema;
    $sqlt->producer($db);

    my $filename = $self->_ddl_filename($db, [ $version ], $dir);
    if (-e $filename && ($version eq $schema_version )) {
      # if we are dumping the current version, overwrite the DDL
      carp "Overwriting existing DDL file - $filename";
      unlink $filename;
    }

    my $output = $sqlt->translate;
    if(!$output) {
      carp("Failed to translate to $db, skipping. (" . $sqlt->error . ")");
      next;
    }
    my $file;
    unless( open $file, q(>), $filename ) {
      $self->throw_exception("Can't open $filename for writing ($!)");
      next;
    }
    print {$file} $output;
    close $file;
  }
}

method prepare_update($version, $preversion) {
  my $schema    = $self->schema;
  my $databases = $self->databases;
  my $dir       = $self->upgrade_directory;
  my $sqltargs  = $self->sqltargs;

  unless( -d $dir ) {
    carp "Upgrade directory $dir does not exist, using ./\n";
    $dir = "./";
  }

  my $schema_version = $schema->schema_version || '1.x';
  $version ||= $schema_version;

  $sqltargs = {
    add_drop_table => 1,
    ignore_constraint_names => 1,
    ignore_index_names => 1,
    %{$sqltargs}
  };

  my $sqlt = SQL::Translator->new( $sqltargs );

  $sqlt->parser('SQL::Translator::Parser::DBIx::Class');
  my $sqlt_schema = $sqlt->translate({ data => $schema })
    or $self->throw_exception ($sqlt->error);

  foreach my $db (@$databases) {
    $sqlt->reset;
    $sqlt->{schema} = $sqlt_schema;
    $sqlt->producer($db);

    my $prefilename = $self->_ddl_filename($db, [ $preversion ], $dir);
    unless(-e $prefilename) {
      carp("No previous schema file found ($prefilename)");
      next;
    }

    my $diff_file = $self->_ddl_filename($db, [ $preversion, $version ], $dir );
    if(-e $diff_file) {
      carp("Overwriting existing diff file - $diff_file");
      unlink $diff_file;
    }

    my $source_schema;
    {
      my $t = SQL::Translator->new({
         %{$sqltargs},
         debug => 0,
         trace => 0,
      });

      $t->parser( $db ) # could this really throw an exception?
        or $self->throw_exception ($t->error);

      my $out = $t->translate( $prefilename )
        or $self->throw_exception ($t->error);

      $source_schema = $t->schema;

      $source_schema->name( $prefilename )
        unless  $source_schema->name;
    }

    # The "new" style of producers have sane normalization and can support
    # diffing a SQL file against a DBIC->SQLT schema. Old style ones don't
    # And we have to diff parsed SQL against parsed SQL.
    my $dest_schema = $sqlt_schema;

    unless ( "SQL::Translator::Producer::$db"->can('preprocess_schema') ) {
      my $t = SQL::Translator->new({
         %{$sqltargs},
         debug => 0,
         trace => 0,
      });

      $t->parser( $db ) # could this really throw an exception?
        or $self->throw_exception ($t->error);

      my $filename = $self->_ddl_filename($db, [ $version ], $dir);
      my $out = $t->translate( $filename )
        or $self->throw_exception ($t->error);

      $dest_schema = $t->schema;

      $dest_schema->name( $filename )
        unless $dest_schema->name;
    }

    my $diff = SQL::Translator::Diff::schema_diff(
       $source_schema, $db,
       $dest_schema,   $db,
       $sqltargs
    );
    my $file;
    unless(open $file, q(>), $diff_file) {
      $self->throw_exception("Can't write to $diff_file ($!)");
      next;
    }
    print {$file} $diff;
    close $file;
  }
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

method _upgrade_single_step {
  my @version_set = @{ shift @_ };
  my $db_version = $self->db_version;
  my $upgrade_file = $self->_ddl_filename(
    $self->storage->sqlt_type,
    \@version_set,
    $self->upgrade_directory,
  );

  unless (-f $upgrade_file) {
    # croak?
    carp "Upgrade not possible, no upgrade file found ($upgrade_file), please create one\n";
    return;
  }

  carp "DB version ($db_version) is lower than the schema version (".$self->schema_version."). Attempting upgrade.\n";

  $self->_filedata($self->_read_sql_file($upgrade_file)); # I don't like this --fREW 2010-02-22
  $self->backup if $self->do_backup;
  $self->schema->txn_do(sub { $self->_do_upgrade });

  $self->version_rs->create({
    version     => $version_set[-1],
    # ddl         => $ddl,
    # upgrade_sql => $upgrade_sql,
  });
}

method _do_upgrade { $self->_run_upgrade(qr/.*?/) }

method _run_upgrade($stm) {
  return unless $self->_filedata;
  my @statements = grep { $_ =~ $stm } @{$self->_filedata};

  for (@statements) {
    $self->storage->debugobj->query_start($_) if $self->storage->debug;
    $self->_apply_statement($_);
    $self->storage->debugobj->query_end($_) if $self->storage->debug;
  }
}

method _apply_statement($statement) {
  # croak?
  $self->storage->dbh->do($_) or carp "SQL was: $_"
}

method backup { $self->storage->backup($self->backup_directory) }

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
