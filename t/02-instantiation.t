#!perl

use Test::More;
use Test::Exception;
use File::Path 'remove_tree';

use lib 't/lib';
use DBICDHTest;
use DBICTest;
use DBIx::Class::DeploymentHandler;
my $db = 'dbi:SQLite:db.db';
my @connection = ($db, '', '', { ignore_version => 1 });
my $sql_dir = 't/sql';

DBICDHTest::ready;

VERSION1: {
   use_ok 'DBICVersion_v1';
   my $s = DBICVersion::Schema->connect(@connection);
   ok($s, 'DBICVersion::Schema 1.0 instantiates correctly');
   my $handler = DBIx::Class::DeploymentHandler->new({
      upgrade_directory => $sql_dir,
      schema => $s,
      databases => 'SQLite',
      sqltargs => { add_drop_table => 0 },
   });

   ok($handler, 'DBIx::Class::DeploymentHandler w/1.0 instantiates correctly');

   my $version = $s->schema_version();
   $handler->prepare_install();
   #ok(-e 't/sql/DBICVersion-Schema-schema-1.0-SQLite.sql', 'DDL for 1.0 got created successfully');

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
   ok($s, 'DBICVersion::Schema 2.0 instantiates correctly');
   my $handler = DBIx::Class::DeploymentHandler->new({
      upgrade_directory => $sql_dir,
      schema => $s,
      databases => 'SQLite',
   });

   ok($handler, 'DBIx::Class::DeploymentHandler w/2.0 instantiates correctly');

   $version = $s->schema_version();
   $handler->prepare_install();
   $handler->prepare_upgrade('1.0', $version);
   $handler->prepare_upgrade($version, '1.0');
   #ok(-e 't/sql/DBICVersion-Schema-schema-2.0-SQLite.sql', 'DDL for 2.0 got created successfully');
   #ok(-e 't/sql/DBICVersion-Schema-diff-1.0-2.0-SQLite.sql', 'DDL for migration from 1.0 to 2.0 got created successfully');
   dies_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
         baz => 'frew',
      })
   } 'schema not deployed';
   #$handler->install('1.0');
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
   ok($s, 'DBICVersion::Schema 3.0 instantiates correctly');
   my $handler = DBIx::Class::DeploymentHandler->new({
      upgrade_directory => $sql_dir,
      schema => $s,
      databases => 'SQLite',
   });

   ok($handler, 'DBIx::Class::DeploymentHandler w/3.0 instantiates correctly');

   $version = $s->schema_version();
   $handler->prepare_install;
   $handler->prepare_upgrade( '1.0', $version );
   $handler->prepare_upgrade( '2.0', $version );
   #ok(-e 't/sql/DBICVersion-Schema-schema-3.0-SQLite.sql', 'DDL for 3.0 got created successfully');
   #ok(-e 't/sql/DBICVersion-Schema-diff-1.0-3.0-SQLite.sql', 'DDL for migration from 1.0 to 3.0 got created successfully');
   #ok(-e 't/sql/DBICVersion-Schema-diff-2.0-3.0-SQLite.sql', 'DDL for migration from 2.0 to 3.0 got created successfully');
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
__END__

vim: ts=2 sw=2 expandtab
