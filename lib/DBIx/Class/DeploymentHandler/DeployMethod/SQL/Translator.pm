package DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator;
use Moose;
use Method::Signatures::Simple;
use Try::Tiny;
use SQL::Translator;
require SQL::Translator::Diff;
require DBIx::Class::Storage;   # loaded for type constraint
use autodie;
use File::Path;

with 'DBIx::Class::DeploymentHandler::HandlesDeploy';

use Carp 'carp';

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
  handles => [qw( schema_version )],
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

has databases => (
  coerce  => 1,
  isa     => 'DBIx::Class::DeploymentHandler::Databases',
  is      => 'ro',
  default => sub { [qw( MySQL SQLite PostgreSQL )] },
);

has _filedata => (
  isa => 'ArrayRef[Str]',
  is  => 'rw',
);

has txn_wrap => (
  is => 'ro',
  isa => 'Bool',
  default => 1,
);

method __ddl_consume_with_prefix($type, $versions, $prefix) {
  my $base_dir = $self->upgrade_directory;

  my $main    = File::Spec->catfile( $base_dir, $type                         );
  my $generic = File::Spec->catfile( $base_dir, '_generic'                    );
  my $common =  File::Spec->catfile( $base_dir, '_common', $prefix, join q(-), @{$versions} );

  my $dir;
  if (-d $main) {
    $dir = File::Spec->catfile($main, $prefix, join q(-), @{$versions})
  } elsif (-d $generic) {
    $dir = File::Spec->catfile($main, $prefix, join q(-), @{$versions})
  } else {
    die 'PREPARE TO SQL'
  }

  opendir my($dh), $dir;
  my %files = map { $_ => "$dir/$_" } grep { /\.sql$/ && -f "$dir/$_" } readdir($dh);
  closedir $dh;

  if (-d $common) {
    opendir my($dh), $common;
    for my $filename (grep { /\.sql$/ && -f "$common/$_" } readdir($dh)) {
      unless ($files{$filename}) {
        $files{$filename} = "$common/$_";
      }
    }
    closedir $dh;
  }

  return [@files{sort keys %files}]
}

method _ddl_schema_consume_filenames($type, $version) {
  $self->__ddl_consume_with_prefix($type, [ $version ], 'schema')
}

method _ddl_schema_produce_filename($type, $version) {
  my $base_dir = $self->upgrade_directory;
  my $dirname = File::Spec->catfile(
    $base_dir, $type, 'schema', $version
  );
  File::Path::mkpath($dirname) unless -d $dirname;

  return File::Spec->catfile(
    $dirname, '001-auto.sql'
  );
}

method _ddl_schema_up_consume_filenames($type, $versions) {
  $self->__ddl_consume_with_prefix($type, $versions, 'up')
}

method _ddl_schema_down_consume_filenames($type, $versions) {
  $self->__ddl_consume_with_prefix($type, $versions, 'down')
}

method _ddl_schema_up_produce_filename($type, $versions) {
  my $dir = $self->upgrade_directory;

  my $dirname = File::Spec->catfile(
    $dir, $type, 'up', join( q(-), @{$versions} )
  );
  File::Path::mkpath($dirname) unless -d $dirname;

  return File::Spec->catfile(
    $dirname, '001-auto.sql'
  );
}

method _ddl_schema_down_produce_filename($type, $versions, $dir) {
  my $dirname = File::Spec->catfile(
    $dir, $type, 'down', join( q(-), @{$versions} )
  );
  File::Path::mkpath($dirname) unless -d $dirname;

  return File::Spec->catfile(
    $dirname, '001-auto.sql'
  );
}

method _deployment_statements {
  my $type     = $self->storage->sqlt_type;
  my $version  = $self->schema_version;

  for my $filename (@{$self->_ddl_schema_consume_filenames($type, $version)}) {
      open my $file, q(<), $filename
        or carp "Can't open $filename ($!)";
      my @rows = <$file>;
      close $file;
      return join '', @rows;
  }
}

sub _deploy {
  my $self = shift;
  my $storage  = $self->storage;

  my $guard = $self->schema->txn_scope_guard if $self->txn_wrap;

  foreach my $line ( split /;\n/, $self->_deployment_statements ) {
    $line = join '', grep { !/^--/ } split /\n/, $line;
    next if !$line || $line =~ /^BEGIN TRANSACTION|^COMMIT|^\s+$/;
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
  }

  $guard->commit if $self->txn_wrap;
}

sub prepare_install {
  my $self = shift;
  my $schema    = $self->schema;
  my $databases = $self->databases;
  my $dir       = $self->upgrade_directory;
  my $sqltargs  = $self->sqltargs;
  my $version = $schema->schema_version;

  my $sqlt = SQL::Translator->new({
    add_drop_table          => 1,
    ignore_constraint_names => 1,
    ignore_index_names      => 1,
    parser                  => 'SQL::Translator::Parser::DBIx::Class',
    %{$sqltargs}
  });

  my $sqlt_schema = $sqlt->translate({ data => $schema })
    or $self->throw_exception($sqlt->error);

  foreach my $db (@$databases) {
    $sqlt->reset;
    $sqlt->{schema} = $sqlt_schema;
    $sqlt->producer($db);

    my $filename = $self->_ddl_schema_produce_filename($db, $version, $dir);
    if (-e $filename ) {
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

sub prepare_upgrade {
  my ($self, $from_version, $to_version, $version_set) = @_;

  $from_version ||= $self->db_version;
  $to_version   ||= $self->schema_version;

  # for updates prepared automatically (rob's stuff)
  # one would want to explicitly set $version_set to
  # [$to_version]
  $version_set  ||= [$from_version, $to_version];

  $self->_prepare_changegrade($from_version, $to_version, $version_set, 'up');
}

sub prepare_downgrade {
  my ($self, $from_version, $to_version, $version_set) = @_;

  $from_version ||= $self->db_version;
  $to_version   ||= $self->schema_version;

  # for updates prepared automatically (rob's stuff)
  # one would want to explicitly set $version_set to
  # [$to_version]
  $version_set  ||= [$from_version, $to_version];

  $self->_prepare_changegrade($from_version, $to_version, $version_set, 'down');
}

method _prepare_changegrade($from_version, $to_version, $version_set, $direction) {
  my $schema    = $self->schema;
  my $databases = $self->databases;
  my $dir       = $self->upgrade_directory;
  my $sqltargs  = $self->sqltargs;

  my $schema_version = $schema->schema_version;

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

    my $prefilename = $self->_ddl_schema_produce_filename($db, $from_version, $dir);
    unless(-e $prefilename) {
      carp("No previous schema file found ($prefilename)");
      next;
    }
    my $diff_file_method = "_ddl_schema_${direction}_produce_filename";
    my $diff_file = $self->$diff_file_method($db, $version_set, $dir );
    if(-e $diff_file) {
      carp("Overwriting existing $direction-diff file - $diff_file");
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

      my $filename = $self->_ddl_schema_produce_filename($db, $to_version, $dir);
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

# these are exactly the same for now
sub _downgrade_single_step {
  my $self = shift;
  my @version_set = @{ shift @_ };
  my @upgrade_files = @{$self->_ddl_schema_up_consume_filenames(
    $self->storage->sqlt_type,
    \@version_set,
  )};

  for my $upgrade_file (@upgrade_files) {
    unless (-f $upgrade_file) {
      # croak?
      carp "Upgrade not possible, no upgrade file found ($upgrade_file), please create one\n";
      return;
    }

    $self->_filedata($self->_read_sql_file($upgrade_file)); # I don't like this --fREW 2010-02-22

    my $guard = $self->schema->txn_scope_guard if $self->txn_wrap;
    $self->_do_upgrade;
    $guard->commit if $self->txn_wrap;
  }
}

sub _upgrade_single_step {
  my $self = shift;
  my @version_set = @{ shift @_ };
  my @upgrade_files = @{$self->_ddl_schema_up_consume_filenames(
    $self->storage->sqlt_type,
    \@version_set,
  )};

  for my $upgrade_file (@upgrade_files) {
    unless (-f $upgrade_file) {
      # croak?
      carp "Upgrade not possible, no upgrade file found ($upgrade_file), please create one\n";
      return;
    }

    $self->_filedata($self->_read_sql_file($upgrade_file)); # I don't like this --fREW 2010-02-22
    my $guard = $self->schema->txn_scope_guard if $self->txn_wrap;
    $self->_do_upgrade;
    $guard->commit if $self->txn_wrap;
  }
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

1;

__END__

vim: ts=2 sw=2 expandtab
