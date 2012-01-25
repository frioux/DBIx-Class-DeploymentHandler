#!perl

use strict;
use warnings;

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::Deprecated';

use File::Path 'remove_tree';
use Test::More;
use Test::Exception;

DBICDHTest::ready;

my $dbh = DBICDHTest::dbh();
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = 't/sql';

VERSION1: {
  use_ok 'DBICVersion_v1';
  my $s = DBICVersion::Schema->connect(@connection);
  is $s->schema_version, '1.0', 'schema version is at 1.0';
  ok($s, 'DBICVersion::Schema 1.0 instantiates correctly');
  my $handler = Deprecated->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
    sql_translator_args => { add_drop_table => 0 },
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/1.0 instantiates correctly');

  my $version = $s->schema_version();
  $handler->prepare_deploy();

  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
    })
  } 'schema not deployed';
  $handler->install;
  dies_ok {
    $handler->install;
  } 'cannot install twice';
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
    })
  } 'schema is deployed';
}

VERSION2: {
  use_ok 'DBICVersion_v2';
  my $s = DBICVersion::Schema->connect(@connection);
  is $s->schema_version, '2.0', 'schema version is at 2.0';
  ok($s, 'DBICVersion::Schema 2.0 instantiates correctly');
  my $handler = Deprecated->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/2.0 instantiates correctly');

  my $version = $s->schema_version();
  $handler->prepare_deploy();
  $handler->prepare_upgrade({ from_version => '1.0', to_version => $version });
  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema not deployed';
  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema not uppgrayyed';
  $handler->upgrade;
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema is deployed';
}

VERSION3: {
  use_ok 'DBICVersion_v3';
  my $s = DBICVersion::Schema->connect(@connection);
  is $s->schema_version, '3.0', 'schema version is at 3.0';
  ok($s, 'DBICVersion::Schema 3.0 instantiates correctly');
  my $handler = Deprecated->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/3.0 instantiates correctly');

  my $version = $s->schema_version();
  $handler->prepare_deploy;
  $handler->prepare_upgrade({ from_version => '2.0', to_version => $version });
  dies_ok {
    $s->resultset('Foo')->create({
        bar => 'frew',
        baz => 'frew',
        biff => 'frew',
      })
  } 'schema not deployed';
  $handler->upgrade;
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
      biff => 'frew',
    })
  } 'schema is deployed';
}

done_testing;
