#!perl

use strict;
use warnings;

use lib 't/lib';
use lib 't/alt-result-class-lib';
use DBICDHTest;
use DBIx::Class::DeploymentHandler;
use aliased 'DBIx::Class::DeploymentHandler', 'DH';

use Test::More;
use File::Temp 'tempdir';
use Test::Fatal qw(lives_ok dies_ok);

use_ok 'DBICVersion_v1';
$DBICVersion::Schema::VERSION = 1;

use_ok 'DBICVersionAlt_v2';
$DBICVersionAlt::Schema::VERSION = 2;

my $dbh = DBICDHTest::dbh();
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = tempdir( CLEANUP => 1 );

my $s1 = DBICVersion::Schema->connect(@connection);
ok($s1, 'DBICVersion::Schema 1 instantiates correctly');

my $s2 = DBICVersionAlt::Schema->connect(@connection);
ok($s2, 'DBICVersionAlt::Schema 2 instantiates correctly');

my $handler1 = DH->new({
  script_directory => "$sql_dir/dh",
  schema => $s1,
  databases => 'SQLite',
  sql_translator_args => { add_drop_table => 0 },
});
ok($handler1, 'DBIx::Class::DeploymentHandler w/1 instantiates correctly');

my $handler2 = DH->new({
  script_directory => "$sql_dir/dh-alt",
  schema => $s2,
  databases => 'SQLite',
  version_source => 'DBICDHVersionAlt',
  version_class => 'DBICVersionAlt::Version',
  sql_translator_args => { add_drop_table => 0 },
});
ok($handler2, 'DBIx::Class::DeploymentHandler w/2 instantiates correctly');

STANDARD: {
  my $version = $s1->schema_version;
  $handler1->prepare_install;

  dies_ok {
    $s1->resultset('Foo')->create({
      bar => 'frew',
    })
  } 'schema not deployed';
  $handler1->install({ version => 1 });
  lives_ok {
    $s1->resultset('Foo')->create({
      bar => 'frew',
    })
  } 'schema is deployed';
}

ALT: {
  my $version = $s2->schema_version();
  $handler2->prepare_install;
  dies_ok {
    $s2->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema not deployed';
  $handler2->install({ version => 2 });
  lives_ok {
    $s2->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema is deployed';
}

is($handler1->database_version, 1, 'schema 1 version correctly set');
is($handler2->database_version, 2, 'schema 2 version correctly set');

done_testing;
