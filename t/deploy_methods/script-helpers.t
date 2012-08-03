#!perl

use strict;
use warnings;

use Test::More;
use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::ScriptHelpers ':all';;
use Test::Fatal;

use lib 't/lib';

use DBICVersion_v1;
use DBICDHTest;

my $dbh = DBICDHTest->dbh;
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $schema = DBICVersion::Schema->connect(@connection);
$schema->deploy;

subtest dbh => sub {
   my $ran;
   dbh(sub {
      my ($dbh, $versions) = @_;

      $ran = 1;

      is($dbh, $schema->storage->dbh, 'dbh is correctly reused');
      is_deeply $versions, [1,2], 'version correctly passed';
      isa_ok($dbh, 'DBI::db');
   })->($schema, [1,2]);

   ok $ran, 'coderef ran';
};

subtest schema_from_schema_loader => sub {
   use Test::Requires;
   test_requires('DBIx::Class::Schema::Loader');
   my $build_sl_test = sub {
      my @connection = @_;

      return sub {
         my $ran;
         my $outer_schema = DBICVersion::Schema->connect(@connection);
         $outer_schema->deploy;
         schema_from_schema_loader({ naming => 'v4' }, sub {
            my ($schema, $versions) = @_;

            $ran = 1;

            is(
               $outer_schema->storage->dbh,
               $schema->storage->dbh,
               'dbh is correctly reused',
            );
            is_deeply $versions, [2,3], 'version correctly passed';
            like(ref $schema, qr/SHSchema::\d+/, 'schema has expected type');
            isa_ok($schema, 'DBIx::Class::Schema', 'and schema is not totally worthless -');
         })->($outer_schema, [2,3]);

         ok $ran, 'coderef ran';
      }
   };

   subtest 'sub { $dbh }, ...' => $build_sl_test->(
      sub { DBICDHTest->dbh },
      { ignore_version => 1 },
   );
   subtest '$dsn, $user, $pass, ...' => $build_sl_test->(
      'dbi:SQLite::memory:', undef, undef,
      { RaiseError => 1 },
      { ignore_version => 1 }
   );

   subtest '({ dsn => ..., ... })' => $build_sl_test->({
      dsn => 'dbi:SQLite::memory:',
      user => undef,
      password => undef,
      RaiseError => 1,
      ignore_version => 1,
   });

   subtest '({ dbh_maker => ..., ... })' => $build_sl_test->({
      dbh_maker => sub { DBICDHTest->dbh },
      RaiseError => 1,
      ignore_version => 1,
   });

   subtest '({ dbh_maker => ..., ... })' => $build_sl_test->({
      dbh_maker => sub { DBICDHTest->dbh },
      RaiseError => 1,
      ignore_version => 1,
   });

   subtest 'error handling' => sub {
      my $outer_schema = DBICVersion::Schema->connect(
         'dbi:SQLite::memory:', undef, undef,
         { RaiseError => 1 },
         { ignore_version => 1 },
      );
      $outer_schema->deploy;
      like(exception {
         schema_from_schema_loader({ naming => 'v4' }, sub {
            my ($schema, $versions) = @_;

            $schema->resultset('foo')
         })->($outer_schema, [2,3]);
      }, qr/Foo <== Possible Match/, 'correct error');
   };
};

done_testing;

