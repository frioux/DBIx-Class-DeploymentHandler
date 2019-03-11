#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal qw(lives_ok dies_ok);

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
use IO::All;
use File::Temp qw(tempfile tempdir);

my $dbh = DBICDHTest::dbh();
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = tempdir( CLEANUP => 1 );
my (undef, $stuffthatran_fn) = tempfile(OPEN => 0);
my $snippet = qq^sub {open my \$fh, ">>", '$stuffthatran_fn'; use Data::Dumper::Concise; print {\$fh} join(",", \@{\$_[1]||[]}) . "\\n";  }^;

for (map io->dir($sql_dir, '_common',  $_, '_any'), qw(initialize upgrade downgrade deploy)) {
   $_->mkpath;
   $_->catfile('000-win.pl')->print($snippet);
}

for (map io->dir($sql_dir, 'SQLite',  $_, '_any'), qw(initialize upgrade downgrade deploy)) {
   $_->mkpath;
   $_->catfile('000-win2.pl')->print($snippet);
}

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

   my $dir = io->dir($sql_dir, qw(SQLite initialize 1.0 ));
   $dir->mkpath;
   my (undef, $fn) = tempfile(OPEN => 0);
   $dir->catfile('003-semiautomatic.pl')->print("sub { open my \$fh, '>', '$fn'}");
   $dm->initialize({ version => '1.0' });

   ok -e $fn, 'code got run in preinit';
   unlink $fn;

   dies_ok {$dm->prepare_deploy} 'prepare_deploy dies if you run it twice' ;

   ok(
      io->file($sql_dir, qw(SQLite deploy 1.0 001-auto.sql ))->exists,
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

   my $version = $s->schema_version();
   $dm->prepare_deploy;
   ok(
      io->file($sql_dir, qw(SQLite deploy 2 001-auto.sql ))->exists,
      '2.0 schema gets generated properly'
   );
   my $upgradedir = io->dir($sql_dir, qw(SQLite upgrade 1.0-2 ));
   $upgradedir->mkpath;
   $dm->prepare_upgrade({
     from_version => '1.0',
     to_version => '2',
     version_set => [qw(1.0 2)]
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
      $upgradedir->catfile('001-auto.sql')->exists,
      '1.0-2.0 diff gets generated properly and default start and end versions get set'
   );
   my $downgradedir = io->dir($sql_dir, qw(SQLite downgrade 2-1.0 ));
   $downgradedir->mkpath;
   $dm->prepare_downgrade({
     from_version => $version,
     to_version => '1.0',
     version_set => [$version, '1.0']
   });
   ok(
      $downgradedir->catfile('001-auto.sql')->exists,
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

   my $upgrade12 = io->dir($sql_dir, qw(_common upgrade 1.0-2 ));
   $upgrade12->mkpath;
   $upgrade12->catfile('002-semiautomatic.sql')->print(qq<INSERT INTO Foo (bar, baz) VALUES ("hello", "world");\n\n>);
   $upgrade12->catfile('003-semiautomatic.pl')->print(<<'EOF');
      sub {
         my $schema = shift;
         $schema->resultset('Foo')->create({
            bar => 'goodbye',
            baz => 'blue skies',
         })
      }
EOF

   $dm->upgrade_single_step({ version_set => [qw( 1.0 2 )] });
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
   $dm->downgrade_single_step({ version_set => [qw( 2 1.0 )] });
   dies_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
         baz => 'frew',
      })
   } 'schema is downgrayyed';
   $dm->upgrade_single_step({ version_set => [qw( 1.0 2 )] });
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

   my $version = $s->schema_version();
   $dm->prepare_deploy;
   ok(
      io->file($sql_dir, qw(SQLite deploy 3.0 001-auto.sql ))->exists,
      '2.0 schema gets generated properly'
   );
   $dm->prepare_downgrade({
     from_version => $version,
     to_version => '1.0',
     version_set => [$version, '1.0']
   });
   ok(
      io->file($sql_dir, qw(SQLite downgrade 3.0-1.0 001-auto.sql ))->exists,
      '3.0-1.0 diff gets generated properly'
   );
   $dm->prepare_upgrade({
     from_version => '1.0',
     to_version => $version,
     version_set => ['1.0', $version]
   });
   ok(
      io->file($sql_dir, qw(SQLite upgrade 1.0-3.0 001-auto.sql ))->exists,
      '1.0-3.0 diff gets generated properly'
   );
   $dm->prepare_upgrade({
     from_version => '2',
     to_version => $version,
     version_set => ['2', $version]
   });
   dies_ok {
      $dm->prepare_upgrade({
        from_version => '2',
        to_version => $version,
        version_set => ['2', $version]
      });
      }
   'prepare_upgrade dies if you clobber an existing upgrade file' ;
   ok(
      io->file($sql_dir, qw(SQLite upgrade 1.0-2 001-auto.sql ))->exists,
      '2.0-3.0 diff gets generated properly'
   );
   dies_ok {
      $s->resultset('Foo')->create({
            bar => 'frew',
            baz => 'frew',
            biff => 'frew',
         })
   } 'schema not deployed';
   $dm->upgrade_single_step({ version_set => [qw( 2 3.0 )] });
   lives_ok {
      $s->resultset('Foo')->create({
         bar => 'frew',
         baz => 'frew',
         biff => 'frew',
      })
   } 'schema is deployed';
   dies_ok {
      $dm->upgrade_single_step({ version_set => [qw( 2 3.0 )] });
   } 'dies when sql dir does not exist';
}

my $stuff_that_ran = io->file($stuffthatran_fn)->slurp;
is $stuff_that_ran,
'

1.0
1.0
1.0,2
1.0,2
2,1.0
2,1.0
1.0,2
1.0,2
2,3.0
2,3.0
2,3.0
2,3.0
', '_any got ran the right amount of times with the right args';
unlink $stuffthatran_fn;

done_testing;
#vim: ts=2 sw=2 expandtab
