#!perl

use Test::More;
use Test::Exception;

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
use File::Spec::Functions;
use File::Path qw(rmtree mkpath);

my $db = 'dbi:SQLite:db.db';
my @connection = ($db, '', '', { ignore_version => 1 });
my $sql_dir = 't/sql';

DBICDHTest::ready;

VERSION1: {
   use_ok 'DBICVersion_v1';
   my $s = DBICVersion::Schema->connect(@connection);
   my $dm = Translator->new({
      schema            => $s,
      script_directory => $sql_dir,
      databases         => ['SQLite'],
      sql_translator_args          => { add_drop_table => 0 },
   });

   ok( $dm, 'DBIC::DH::DM::SQL::Translator gets instantiated correctly' );

   $dm->prepare_deploy;

   mkpath(catfile(qw( t sql SQLite initialize 1.0 )));
   open my $prerun, '>',
      catfile(qw( t sql SQLite initialize 1.0 003-semiautomatic.pl ));
   print {$prerun} "sub {use File::Touch; touch(q(foobar));}";
   close $prerun;
   $dm->initialize({ version => '1.0' });

   ok -e 'foobar';

   {
      my $warned = 0;
      local $SIG{__WARN__} = sub{$warned = 1};
      $dm->prepare_deploy;
      ok( $warned, 'prepare_deploy warns if you run it twice' );
   }

   ok(
      -f catfile(qw( t sql SQLite deploy 1.0 001-auto.sql )),
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
   my $dm = Translator->new({
      schema            => $s,
      script_directory => $sql_dir,
      databases         => ['SQLite'],
      sql_translator_args          => { add_drop_table => 0 },
      txn_wrap          => 1,
   });

   ok( $dm, 'DBIC::DH::SQL::Translator w/2.0 instantiates correctly');

   $version = $s->schema_version();
   $dm->prepare_deploy;
   ok(
      -f catfile(qw( t sql SQLite deploy 2.0 001-auto.sql )),
      '2.0 schema gets generated properly'
   );
   mkpath(catfile(qw( t sql SQLite upgrade 1.0-2.0 )));
   $dm->prepare_upgrade({
     from_version => '1.0',
     to_version => '2.0',
     version_set => [qw(1.0 2.0)]
   });

   {
      my $warned = 0;
      local $SIG{__WARN__} = sub{$warned = 1};
      $dm->prepare_upgrade({
        from_version => '0.0',
        to_version => '1.0',
        version_set => [qw(0.0 1.0)]
      });
      ok( $warned, 'prepare_upgrade with a bogus preversion warns' );
   }
   ok(
      -f catfile(qw( t sql SQLite upgrade 1.0-2.0 001-auto.sql )),
      '1.0-2.0 diff gets generated properly and default start and end versions get set'
   );
   mkpath(catfile(qw( t sql SQLite downgrade 2.0-1.0 )));
   $dm->prepare_downgrade({
     from_version => $version,
     to_version => '1.0',
     version_set => [$version, '1.0']
   });
   ok(
      -f catfile(qw( t sql SQLite downgrade 2.0-1.0 001-auto.sql )),
      '2.0-1.0 diff gets generated properly'
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

   mkpath catfile(qw( t sql _common upgrade 1.0-2.0 ));
   open my $common, '>',
      catfile(qw( t sql _common upgrade 1.0-2.0 002-semiautomatic.sql ));
   print {$common} qq<INSERT INTO Foo (bar, baz) VALUES ("hello", "world");\n\n>;
   close $common;

   open my $common_pl, '>',
      catfile(qw( t sql _common upgrade 1.0-2.0 003-semiautomatic.pl ));
   print {$common_pl} q|
      sub {
         my $schema = shift;
         $schema->resultset('Foo')->create({
            bar => 'goodbye',
            baz => 'blue skies',
         })
      }
   |;
   close $common_pl;

   $dm->upgrade_single_step({ version_set => [qw( 1.0 2.0 )] });
   is( $s->resultset('Foo')->search({
         bar => 'hello',
         baz => 'world',
      })->count, 1, '_common migration got run');
   is( $s->resultset('Foo')->search({
         bar => 'goodbye',
         #baz => 'blue skies',
      })->count, 1, '_common perl migration got run');
   lives_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
         baz => 'frew',
      })
   } 'schema is deployed';
   $dm->downgrade_single_step({ version_set => [qw( 2.0 1.0 )] });
   dies_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
         baz => 'frew',
      })
   } 'schema is downgrayyed';
   $dm->upgrade_single_step({ version_set => [qw( 1.0 2.0 )] });
}

VERSION3: {
   use_ok 'DBICVersion_v3';
   my $s = DBICVersion::Schema->connect(@connection);
   my $dm = Translator->new({
      schema            => $s,
      script_directory => $sql_dir,
      databases         => ['SQLite'],
      sql_translator_args          => { add_drop_table => 0 },
      txn_wrap          => 0,
   });

   ok( $dm, 'DBIC::DH::SQL::Translator w/3.0 instantiates correctly');

   $version = $s->schema_version();
   $dm->prepare_deploy;
   ok(
      -f catfile(qw( t sql SQLite deploy 3.0 001-auto.sql )),
      '2.0 schema gets generated properly'
   );
   $dm->prepare_downgrade({
     from_version => $version,
     to_version => '1.0',
     version_set => [$version, '1.0']
   });
   ok(
      -f catfile(qw( t sql SQLite downgrade 3.0-1.0 001-auto.sql )),
      '3.0-1.0 diff gets generated properly'
   );
   $dm->prepare_upgrade({
     from_version => '1.0',
     to_version => $version,
     version_set => ['1.0', $version]
   });
   ok(
      -f catfile(qw( t sql SQLite upgrade 1.0-3.0 001-auto.sql )),
      '1.0-3.0 diff gets generated properly'
   );
   $dm->prepare_upgrade({
     from_version => '2.0',
     to_version => $version,
     version_set => ['2.0', $version]
   });
   {
      my $warned = 0;
      local $SIG{__WARN__} = sub{$warned = 1};
      $dm->prepare_upgrade({
        from_version => '2.0',
        to_version => $version,
        version_set => ['2.0', $version]
      });
      ok( $warned, 'prepare_upgrade warns if you clobber an existing upgrade file' );
   }
   ok(
      -f catfile(qw( t sql SQLite upgrade 1.0-2.0 001-auto.sql )),
      '2.0-3.0 diff gets generated properly'
   );
   dies_ok {
      $s->resultset('Foo')->create({
            bar => 'frew',
            baz => 'frew',
            biff => 'frew',
         })
   } 'schema not deployed';
   $dm->upgrade_single_step({ version_set => [qw( 2.0 3.0 )] });
   lives_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
         baz => 'frew',
         biff => 'frew',
      })
   } 'schema is deployed';
   dies_ok {
      $dm->upgrade_single_step({ version_set => [qw( 2.0 3.0 )] });
   } 'dies when sql dir does not exist';
}
done_testing;
#vim: ts=2 sw=2 expandtab
