package DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator;
use Moose;

use autodie;
use Carp qw( carp croak );

use Method::Signatures::Simple;
use Try::Tiny;

use SQL::Translator;
require SQL::Translator::Diff;

require DBIx::Class::Storage;   # loaded for type constraint
use DBIx::Class::DeploymentHandler::Types;

use File::Path 'mkpath';
use File::Spec::Functions;

with 'DBIx::Class::DeploymentHandler::HandlesDeploy';

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

has txn_wrap => (
  is => 'ro',
  isa => 'Bool',
  default => 1,
);

method __ddl_consume_with_prefix($type, $versions, $prefix) {
  my $base_dir = $self->upgrade_directory;

  my $main    = catfile( $base_dir, $type      );
  my $generic = catfile( $base_dir, '_generic' );
  my $common  =
    catfile( $base_dir, '_common', $prefix, join q(-), @{$versions} );

  my $dir;
  if (-d $main) {
    $dir = catfile($main, $prefix, join q(-), @{$versions})
  } elsif (-d $generic) {
    $dir = catfile($generic, $prefix, join q(-), @{$versions});
  } else {
    croak "neither $main or $generic exist; please write/generate some SQL";
  }

  opendir my($dh), $dir;
  my %files = map { $_ => "$dir/$_" } grep { /\.(?:sql|pl)$/ && -f "$dir/$_" } readdir $dh;
  closedir $dh;

  if (-d $common) {
    opendir my($dh), $common;
    for my $filename (grep { /\.(?:sql|pl)$/ && -f catfile($common,$_) } readdir $dh) {
      unless ($files{$filename}) {
        $files{$filename} = catfile($common,$filename);
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
  my $dirname = catfile( $self->upgrade_directory, $type, 'schema', $version );
  mkpath($dirname) unless -d $dirname;

  return catfile( $dirname, '001-auto.sql' );
}

method _ddl_schema_up_consume_filenames($type, $versions) {
  $self->__ddl_consume_with_prefix($type, $versions, 'up')
}

method _ddl_schema_down_consume_filenames($type, $versions) {
  $self->__ddl_consume_with_prefix($type, $versions, 'down')
}

method _ddl_schema_up_produce_filename($type, $versions) {
  my $dir = $self->upgrade_directory;

  my $dirname = catfile( $dir, $type, 'up', join q(-), @{$versions});
  mkpath($dirname) unless -d $dirname;

  return catfile( $dirname, '001-auto.sql'
  );
}

method _ddl_schema_down_produce_filename($type, $versions, $dir) {
  my $dirname = catfile( $dir, $type, 'down', join q(-), @{$versions} );
  mkpath($dirname) unless -d $dirname;

  return catfile( $dirname, '001-auto.sql');
}

method _run_sql_and_perl($filenames) {
  my @files = @{$filenames};
  my $storage = $self->storage;


  my $guard = $self->schema->txn_scope_guard if $self->txn_wrap;

  my $sql;
  for my $filename (@files) {
    if ($filename =~ /\.sql$/) {
      my @sql = @{$self->_read_sql_file($filename)};
      $sql .= join "\n", @sql;

      foreach my $line (@sql) {
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
    } elsif ( $filename =~ /^(.+)\.pl$/ ) {
      my $package = $1;
      my $filedata = do { local( @ARGV, $/ ) = $filename; <> };
      # make the package name more palateable to perl
      $package =~ s/\W/_/g;

      no warnings 'redefine';
      eval "package $package;\n\n$filedata";
      use warnings;

      if (my $fn = $package->can('run')) {
        $fn->($self->schema);
      } else {
        carp "$filename should define a run method that takes a schema but it didn't!";
      }
    } else {
      croak "A file got to deploy that wasn't sql or perl!";
    }
  }

  $guard->commit if $self->txn_wrap;

  return $sql;
}

sub deploy {
  my $self = shift;

  return $self->_run_sql_and_perl($self->_ddl_schema_consume_filenames(
    $self->storage->sqlt_type,
    $self->schema_version
  ));
}

sub _prepare_install {
  my $self = shift;
  my $sqltargs  = { %{$self->sqltargs}, %{shift @_} };
  my $to_file   = shift;
  my $schema    = $self->schema;
  my $databases = $self->databases;
  my $dir       = $self->upgrade_directory;
  my $version = $schema->schema_version;

  my $sqlt = SQL::Translator->new({
    add_drop_table          => 1,
    ignore_constraint_names => 1,
    ignore_index_names      => 1,
    parser                  => 'SQL::Translator::Parser::DBIx::Class',
    %{$sqltargs}
  });

  my $sqlt_schema = $sqlt->translate( data => $schema )
    or croak($sqlt->error);

  foreach my $db (@$databases) {
    $sqlt->reset;
    $sqlt->{schema} = $sqlt_schema;
    $sqlt->producer($db);

    my $filename = $self->$to_file($db, $version, $dir);
    if (-e $filename ) {
      carp "Overwriting existing DDL file - $filename";
      unlink $filename;
    }

    my $output = $sqlt->translate;
    if(!$output) {
      carp("Failed to translate to $db, skipping. (" . $sqlt->error . ")");
      next;
    }
    open my $file, q(>), $filename;
    print {$file} $output;
    close $file;
  }
}

sub _resultsource_install_filename {
  my ($self, $source_name) = @_;
  return sub {
    my ($self, $type, $version) = @_;
    my $dirname = catfile( $self->upgrade_directory, $type, 'schema', $version );
    mkpath($dirname) unless -d $dirname;

    return catfile( $dirname, "001-auto-$source_name.sql" );
  }
}

sub install_resultsource {
  my ($self, $source, $version) = @_;

  my $rs_install_file =
    $self->_resultsource_install_filename($source->source_name);

  my $files = [
     $self->$rs_install_file(
      $self->storage->sqlt_type,
      $version,
    )
  ];
  $self->_run_sql_and_perl($files);
}

sub prepare_resultsource_install {
  my $self = shift;
  my $source = shift;

  my $filename = $self->_resultsource_install_filename($source->source_name);
  $self->_prepare_install({
      parser_args => { sources => [$source->source_name], }
    }, $filename);
}

sub prepare_install {
  my $self = shift;
  $self->_prepare_install({}, '_ddl_schema_produce_filename');
}

sub prepare_upgrade {
  my ($self, $from_version, $to_version, $version_set) = @_;
  $self->_prepare_changegrade($from_version, $to_version, $version_set, 'up');
}

sub prepare_downgrade {
  my ($self, $from_version, $to_version, $version_set) = @_;

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
  my $sqlt_schema = $sqlt->translate( data => $schema )
    or croak($sqlt->error);

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
        or croak($t->error);

      my $out = $t->translate( $prefilename )
        or croak($t->error);

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
        or croak($t->error);

      my $filename = $self->_ddl_schema_produce_filename($db, $to_version, $dir);
      my $out = $t->translate( $filename )
        or croak($t->error);

      $dest_schema = $t->schema;

      $dest_schema->name( $filename )
        unless $dest_schema->name;
    }

    my $diff = SQL::Translator::Diff::schema_diff(
       $source_schema, $db,
       $dest_schema,   $db,
       $sqltargs
    );
    open my $file, q(>), $diff_file;
    print {$file} $diff;
    close $file;
  }
}

method _read_sql_file($file) {
  return unless $file;

  open my $fh, '<', $file;
  my @data = split /;\n/, join '', <$fh>;
  close $fh;

  @data = grep {
    $_ && # remove blank lines
    !/^(BEGIN|BEGIN TRANSACTION|COMMIT)/ # strip txn's
  } map {
    s/^\s+//; s/\s+$//; # trim whitespace
    join '', grep { !/^--/ } split /\n/ # remove comments
  } @data;

  return \@data;
}

sub downgrade_single_step {
  my $self = shift;
  my $version_set = shift @_;

  my $sql = $self->_run_sql_and_perl($self->_ddl_schema_down_consume_filenames(
    $self->storage->sqlt_type,
    $version_set,
  ));

  return ['', $sql];
}

sub upgrade_single_step {
  my $self = shift;
  my $version_set = shift @_;

  my $sql = $self->_run_sql_and_perl($self->_ddl_schema_up_consume_filenames(
    $self->storage->sqlt_type,
    $version_set,
  ));
  return ['', $sql];
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=attr schema
=attr storage
=attr sqltargs

#rename
=attr upgrade_directory

The directory (default C<'sql'>) that upgrades are stored in

=attr databases

The types of databases (default C<< [qw( MySQL SQLite PostgreSQL )] >>) to
generate files for

=attr txn_wrap

=method __ddl_consume_with_prefix
=method _ddl_schema_consume_filenames
=method _ddl_schema_produce_filename
=method _ddl_schema_up_consume_filenames
=method _ddl_schema_down_consume_filenames
=method _ddl_schema_up_produce_filenames
=method _ddl_schema_down_produce_filenames
=method _resultsource_install_filename
=method _run_sql_and_perl

=method _prepare_install
=method _prepare_changegrade
=method _read_sql_file

=method deploy
=method install_resultsource
=method prepare_resultsouce_install
=method prepare_install
=method prepare_upgrade
=method prepare_downgrade
=method upgrade_single_step
=method downgrade_single_step

vim: ts=2 sw=2 expandtab
