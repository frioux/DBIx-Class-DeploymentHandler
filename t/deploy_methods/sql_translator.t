#!perl

use Test::More;
use Test::Exception;

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
use File::Spec::Functions;

my $db = 'dbi:SQLite:db.db';
my @connection = ($db, '', '', { ignore_version => 1 });
my $sql_dir = 't/sql';

DBICDHTest::ready;

VERSION1: {
   use_ok 'DBICVersion_v1';
   my $s = DBICVersion::Schema->connect(@connection);
   my $dm = Translator->new({
      schema            => $s,
      upgrade_directory => $sql_dir,
      databases         => ['SQLite'],
      sqltargs          => { add_drop_table => 0 },
   });

   ok( $dm, 'DBIC::DH::DM::SQL::Translator gets instantiated correctly' );

   $dm->prepare_install;

   ok(
      -f catfile(qw( t sql SQLite schema 1.0 001-auto.sql )),
      '1.0 schema gets generated properly'
   );

   dies_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
      })
   } 'schema not deployed';

   $dm->_deploy;

   lives_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
      })
   } 'schema is deployed';
}

VERSION2: {
   use_ok 'DBICVersion_v2';
   my $s = DBICVersion::Schema->connect(@connection);
   my $dm = Translator->new({
      schema            => $s,
      upgrade_directory => $sql_dir,
      databases         => ['SQLite'],
      sqltargs          => { add_drop_table => 0 },
   });

   ok( $dm, 'DBIC::DH::SQL::Translator w/2.0 instantiates correctly');

   $version = $s->schema_version();
   $dm->prepare_install();
   ok(
      -f catfile(qw( t sql SQLite schema 2.0 001-auto.sql )),
      '2.0 schema gets generated properly'
   );
   $dm->prepare_upgrade('1.0', $version);
   ok(
      -f catfile(qw( t sql SQLite up 1.0-2.0 001-auto.sql )),
      '1.0-2.0 diff gets generated properly'
   );
   $dm->prepare_downgrade($version, '1.0');
   ok(
      -f catfile(qw( t sql SQLite down 2.0-1.0 001-auto.sql )),
      '1.0-2.0 diff gets generated properly'
   );
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
   $dm->_upgrade_single_step([qw( 1.0 2.0 )]);
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
   my $dm = Translator->new({
      schema            => $s,
      upgrade_directory => $sql_dir,
      databases         => ['SQLite'],
      sqltargs          => { add_drop_table => 0 },
   });

   ok( $dm, 'DBIC::DH::SQL::Translator w/3.0 instantiates correctly');

   $version = $s->schema_version();
   $dm->prepare_install;
   ok(
      -f catfile(qw( t sql SQLite schema 3.0 001-auto.sql )),
      '2.0 schema gets generated properly'
   );
   $dm->prepare_upgrade( '1.0', $version );
   ok(
      -f catfile(qw( t sql SQLite up 1.0-2.0 001-auto.sql )),
      '1.0-3.0 diff gets generated properly'
   );
   $dm->prepare_upgrade( '2.0', $version );
   ok(
      -f catfile(qw( t sql SQLite up 1.0-2.0 001-auto.sql )),
      '2.0-3.0 diff gets generated properly'
   );
   dies_ok {
      $s->resultset('Foo')->create({
            bar => 'frew',
            baz => 'frew',
            biff => 'frew',
         })
   } 'schema not deployed';
   $dm->_upgrade_single_step([qw( 2.0 3.0 )]);
   lives_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
         baz => 'frew',
         biff => 'frew',
      })
   } 'schema is deployed';
}
done_testing;
