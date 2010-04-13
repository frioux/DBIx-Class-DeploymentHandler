#!perl

use Test::More;
use Test::Exception;

use lib 't/lib';
use DBICDHTest;
use aliased
   'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::Deprecated';

use File::Spec::Functions;

my $db = 'dbi:SQLite:db.db';
my @connection = ($db, '', '', { ignore_version => 1 });
my $sql_dir = 't/sql';

DBICDHTest::ready;

VERSION1: {
   use_ok 'DBICVersion_v1';
   my $s = DBICVersion::Schema->connect(@connection);
   my $dm = Deprecated->new({
      schema            => $s,
      upgrade_directory => $sql_dir,
      databases         => ['SQLite'],
      sqltargs          => { add_drop_table => 0 },
   });

   ok( $dm, 'DBIC::DH::DM::SQLT::Deprecated gets instantiated correctly' );

   $dm->prepare_deploy;

   ok(
      -f catfile(qw( t sql DBICVersion-Schema-1.0-SQLite.sql )),
      '1.0 schema gets generated properly'
   );

   dies_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
      })
   } 'schema not deployed';
   $dm->deploy;
   lives_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
      })
   } 'schema is deployed';
}

VERSION2: {
   use_ok 'DBICVersion_v2';
   my $s = DBICVersion::Schema->connect(@connection);
   my $dm = Deprecated->new({
      schema            => $s,
      upgrade_directory => $sql_dir,
      databases         => ['SQLite'],
   });

   ok(
      $dm,
      'DBIC::DH::DM::SQLT::Deprecated gets instantiated correctly w/ version 2.0'
   );

   $version = $s->schema_version;
   $dm->prepare_deploy;
   $dm->prepare_upgrade('1.0', $version, ['1.0', $version]);
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
   $dm->upgrade_single_step(['1.0', $version]);
   lives_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
         baz => 'frew',
      })
   } 'schema is deployed';
}
done_testing;
#vim: ts=2 sw=2 expandtab
