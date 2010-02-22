package DBIx::Class::DeploymentHandler;

use Moose;
use Method::Signatures::Simple;
require DBIx::Class::Schema; # loaded for type constraint
require DBIx::Class::Storage; # loaded for type constraint
use Carp 'carp';

has schema => (
   isa      => 'DBIx::Class::Schema',
   is       => 'ro',
   required => 1,
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

has _filedata => (
   is => 'ro',
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

method _build_storage {
   return $self->schema->storage;
}

method install($new_version) {
  # must be called on a fresh database
  if ($self->get_db_version) {
    carp 'Install not possible as versions table already exists in database';
  }

  # default to current version if none passed
  $new_version ||= $self->schema_version();

  if ($new_version) {
    # create versions table and version row
    $self->{vschema}->deploy;
    $self->_set_db_version({ version => $new_version });
  }
}

method deploy {
  $self->next::method(@_);
  $self->install();
}

sub create_upgrade_path {
  ## override this method
}

sub ordered_schema_versions {
  ## override this method
}

method upgrade {
  my $db_version = $self->get_db_version();

  # db unversioned
  unless ($db_version) {
      carp 'Upgrade not possible as database is unversioned. Please call install first.';
      return;
  }

  # db and schema at same version. do nothing
  if ( $db_version eq $self->schema_version ) {
      carp "Upgrade not necessary\n";
      return;
  }

  my @version_list = $self->ordered_schema_versions;

  # if nothing returned then we preload with min/max
  @version_list = ( $db_version, $self->schema_version )
    unless ( scalar(@version_list) );

  # catch the case of someone returning an arrayref
  @version_list = @{ $version_list[0] }
    if ( ref( $version_list[0] ) eq 'ARRAY' );

  # remove all versions in list above the required version
  while ( scalar(@version_list)
      && ( $version_list[-1] ne $self->schema_version ) )
  {
      pop @version_list;
  }

  # remove all versions in list below the current version
  while ( scalar(@version_list) && ( $version_list[0] ne $db_version ) ) {
      shift @version_list;
  }

  # check we have an appropriate list of versions
  if ( scalar(@version_list) < 2 ) {
      die;
  }

  # do sets of upgrade
  while ( scalar(@version_list) >= 2 ) {
      $self->upgrade_single_step( $version_list[0], $version_list[1] );
      shift @version_list;
  }
}

method upgrade_single_step($db_version, $target_version) {
  # db and schema at same version. do nothing
  if ($db_version eq $target_version) {
    carp "Upgrade not necessary\n";
    return;
  }

  # strangely the first time this is called can
  # differ to subsequent times. so we call it
  # here to be sure.
  # XXX - just fix it
  $self->storage->sqlt_type;

  my $upgrade_file = $self->ddl_filename(
                                         $self->storage->sqlt_type,
                                         $target_version,
                                         $self->upgrade_directory,
                                         $db_version,
                                        );

  $self->create_upgrade_path({ upgrade_file => $upgrade_file });

  unless (-f $upgrade_file) {
    carp "Upgrade not possible, no upgrade file found ($upgrade_file), please create one\n";
    return;
  }

  carp "DB version ($db_version) is lower than the schema version (".$self->schema_version."). Attempting upgrade.\n";

  # backup if necessary then apply upgrade
  $self->_filedata($self->_read_sql_file($upgrade_file));
  $self->backup() if($self->do_backup);
  $self->txn_do(sub { $self->do_upgrade() });

  # set row in dbix_class_schema_versions table
  $self->_set_db_version({version => $target_version});
}

method do_upgrade {
  # just run all the commands (including inserts) in order
  $self->run_upgrade(qr/.*?/);
}

method run_upgrade($stm) {
    return unless ($self->_filedata);
    my @statements = grep { $_ =~ $stm } @{$self->_filedata};
    $self->_filedata([ grep { $_ !~ /$stm/i } @{$self->_filedata} ]);

    for (@statements) {
        $self->storage->debugobj->query_start($_) if $self->storage->debug;
        $self->apply_statement($_);
        $self->storage->debugobj->query_end($_) if $self->storage->debug;
    }

    return 1;
}

method apply_statement($statement) {
    $self->storage->dbh->do($_) or carp "SQL was: $_";
}

method get_db_version($rs) {
    my $vtable = $self->{vschema}->resultset('Table');
    my $version = eval {
      $vtable->search({}, { order_by => { -desc => 'installed' }, rows => 1 } )
              ->get_column ('version')
               ->next;
    };
    return $version || 0;
}

method schema_version {}

method backup {
    ## Make each ::DBI::Foo do this
    $self->storage->backup($self->backup_directory());
}

method connection  {
  $self->next::method(@_);
  $self->_on_connect($_[3]);
  return $self;
}

sub _on_connect
{
  my ($self, $args) = @_;

  $args = {} unless $args;

  $self->{vschema} = DBIx::Class::Version->connect(@{$self->storage->connect_info()});
  my $vtable = $self->{vschema}->resultset('Table');

  # useful when connecting from scripts etc
  return if ($args->{ignore_version} || ($ENV{DBIC_NO_VERSION_CHECK} && !exists $args->{ignore_version}));

  # check for legacy versions table and move to new if exists
  my $vschema_compat = DBIx::Class::VersionCompat->connect(@{$self->storage->connect_info()});
  unless ($self->_source_exists($vtable)) {
    my $vtable_compat = $vschema_compat->resultset('TableCompat');
    if ($self->_source_exists($vtable_compat)) {
      $self->{vschema}->deploy;
      map { $vtable->create({ installed => $_->Installed, version => $_->Version }) } $vtable_compat->all;
      $self->storage->dbh->do("DROP TABLE " . $vtable_compat->result_source->from);
    }
  }

  my $pversion = $self->get_db_version();

  if($pversion eq $self->schema_version)
    {
#         carp "This version is already installed\n";
        return 1;
    }

  if(!$pversion)
    {
        carp "Your DB is currently unversioned. Please call upgrade on your schema to sync the DB.\n";
        return 1;
    }

  carp "Versions out of sync. This is " . $self->schema_version .
    ", your database contains version $pversion, please call upgrade on your Schema.\n";
}

sub _create_db_to_schema_diff {
  my $self = shift;

  my %driver_to_db_map = (
                          'mysql' => 'MySQL'
                         );

  my $db = $driver_to_db_map{$self->storage->dbh->{Driver}->{Name}};
  unless ($db) {
    print "Sorry, this is an unsupported DB\n";
    return;
  }

  $self->throw_exception($self->storage->_sqlt_version_error)
    if (not $self->storage->_sqlt_version_ok);

  my $db_tr = SQL::Translator->new({
                                    add_drop_table => 1,
                                    parser => 'DBI',
                                    parser_args => { dbh => $self->storage->dbh }
                                   });

  $db_tr->producer($db);
  my $dbic_tr = SQL::Translator->new;
  $dbic_tr->parser('SQL::Translator::Parser::DBIx::Class');
  $dbic_tr->data($self);
  $dbic_tr->producer($db);

  $db_tr->schema->name('db_schema');
  $dbic_tr->schema->name('dbic_schema');

  # is this really necessary?
  foreach my $tr ($db_tr, $dbic_tr) {
    my $data = $tr->data;
    $tr->parser->($tr, $$data);
  }

  my $diff = SQL::Translator::Diff::schema_diff($db_tr->schema, $db,
                                                $dbic_tr->schema, $db,
                                                { ignore_constraint_names => 1, ignore_index_names => 1, caseopt => 1 });

  my $filename = $self->ddl_filename(
                                         $db,
                                         $self->schema_version,
                                         $self->upgrade_directory,
                                         'PRE',
                                    );
  my $file;
  if(!open($file, ">$filename"))
    {
      $self->throw_exception("Can't open $filename for writing ($!)");
      next;
    }
  print $file $diff;
  close($file);

  carp "WARNING: There may be differences between your DB and your DBIC schema. Please review and if necessary run the SQL in $filename to sync your DB.\n";
}


sub _set_db_version {
  my $self = shift;
  my ($params) = @_;
  $params ||= {};

  my $version = $params->{version} ? $params->{version} : $self->schema_version;
  my $vtable = $self->{vschema}->resultset('Table');

  ##############################################################################
  #                             !!! NOTE !!!
  ##############################################################################
  #
  # The travesty below replaces the old nice timestamp format of %Y-%m-%d %H:%M:%S
  # This is necessary since there are legitimate cases when upgrades can happen
  # back to back within the same second. This breaks things since we relay on the
  # ability to sort by the 'installed' value. The logical choice of an autoinc
  # is not possible, as it will break multiple legacy installations. Also it is
  # not possible to format the string sanely, as the column is a varchar(20).
  # The 'v' character is added to the front of the string, so that any version
  # formatted by this new function will sort _after_ any existing 200... strings.
  my @tm = gettimeofday();
  my @dt = gmtime ($tm[0]);
  my $o = $vtable->create({
    version => $version,
    installed => sprintf("v%04d%02d%02d_%02d%02d%02d.%03.0f",
      $dt[5] + 1900,
      $dt[4] + 1,
      $dt[3],
      $dt[2],
      $dt[1],
      $dt[0],
      $tm[1] / 1000, # convert to millisecs, format as up/down rounded int above
    ),
  });
}

sub _read_sql_file {
  my $self = shift;
  my $file = shift || return;

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

sub _source_exists
{
    my ($self, $rs) = @_;

    my $c = eval {
        $rs->search({ 1, 0 })->count;
    };
    return 0 if $@ || !defined $c;

    return 1;
}

1;
