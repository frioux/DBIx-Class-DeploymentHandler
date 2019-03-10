#!perl

use strict;
use warnings;

use lib 't/version-table-rename-lib';
use DBICDHTest;
use DBIx::Class::DeploymentHandler;
use aliased 'DBIx::Class::DeploymentHandler', 'DH';

use Test::More;
use File::Temp 'tempdir';
use Test::Fatal qw(lives_ok dies_ok);
use IO::All;

my $dbh = DBICDHTest::dbh();
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = tempdir( CLEANUP => 1 );

VERSION1: {
  use_ok 'DBICVersion_v1';
  my $s = DBICVersion::Schema->connect(@connection);
  $DBICVersion::Schema::VERSION = 1;
  ok($s, 'DBICVersion::Schema 1 instantiates correctly');
  my $handler = DH->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
    sql_translator_args => { add_drop_table => 0 },
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/1 instantiates correctly');

  my $version = $s->schema_version;
  $handler->prepare_install;

  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
    })
  } 'schema not deployed';
  $handler->install;
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
    })
  } 'schema is deployed';
}

VERSION2: {
  use_ok 'DBICVersion_v2';
  my $s = DBICVersion::Schema->connect(@connection);
  $DBICVersion::Schema::VERSION = 2;
  $s->unregister_source('__VERSION'); # remove leftover version source
  ok($s, 'DBICVersion::Schema 2 instantiates correctly');

  my $handler = DH->new({
    initial_version => 1,
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
    version_source => 'DBICDHVersion',
    version_class => 'DBICVersion::Version',
  });
  ok($handler, 'DBIx::Class::DeploymentHandler w/2 instantiates correctly');

  my $version = $s->schema_version();
  $handler->prepare_install;
  $handler->prepare_upgrade({ from_version => 1, to_version => $version} );

  # manually add SQL to rename the version table
  io->file($sql_dir, qw(SQLite upgrade 1-2 002-version-table-rename.sql))->print(<<SQL);
    ALTER TABLE dbix_class_deploymenthandler_versions RENAME TO dbic_version;
SQL

  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema not deployed';
  $handler->upgrade;
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema is deployed';

  is $handler->database_version, 2, 'correct schema version is set';
}

done_testing;
