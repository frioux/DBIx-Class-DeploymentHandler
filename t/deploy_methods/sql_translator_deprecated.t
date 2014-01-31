#!perl

use Test::More;
use Test::Fatal qw(lives_ok dies_ok);

use lib 't/lib';
use DBICDHTest;
use aliased
   'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::Deprecated';

use IO::All;
use File::Temp 'tempdir';

my $dbh = DBICDHTest::dbh();
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = tempdir( CLEANUP => 1 );

DBICDHTest::ready;

VERSION1: {
   use_ok 'DBICVersion_v1';
   my $s = DBICVersion::Schema->connect(@connection);
   my $dm = Deprecated->new({
      schema            => $s,
      script_directory => $sql_dir,
      databases         => ['SQLite'],
      sql_translator_args          => { add_drop_table => 0 },
   });

   ok( $dm, 'DBIC::DH::DM::SQLT::Deprecated gets instantiated correctly' );

   $dm->prepare_deploy;

   ok(
      -f io->file($sql_dir, qw(DBICVersion-Schema-1.0-SQLite.sql )) . "",
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
      script_directory => $sql_dir,
      databases         => ['SQLite'],
   });

   ok(
      $dm,
      'DBIC::DH::DM::SQLT::Deprecated gets instantiated correctly w/ version 2.0'
   );

   $version = $s->schema_version;
   $dm->prepare_deploy;
   $dm->prepare_upgrade({
     from_version => '1.0',
     to_version => $version,
     version_set => ['1.0', $version]
   });
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
   $dm->upgrade_single_step({ version_set => ['1.0', $version] });
   lives_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
         baz => 'frew',
      })
   } 'schema is deployed';
}
done_testing;
#vim: ts=2 sw=2 expandtab
