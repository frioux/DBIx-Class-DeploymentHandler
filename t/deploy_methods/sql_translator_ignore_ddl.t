#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal qw(dies_ok exception);

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
use Path::Class qw(dir file);
use File::Temp qw(tempdir);

my $dbh = DBICDHTest::dbh();
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = tempdir( CLEANUP => 1 );

VERSION1: {
   use_ok 'DBICVersion_v1';
   my $s = DBICVersion::Schema->connect(@connection);
   my $dm = Translator->new({
      schema            => $s,
      script_directory => $sql_dir,
      databases         => ['SQLite'],
      sql_translator_args          => { add_drop_table => 0 },
      ignore_ddl => 1,
   });

   ok( $dm, 'DBIC::DH::DM::SQL::Translator gets instantiated correctly' );

   dir($sql_dir, '_common',  'deploy', '_any')->mkpath;
   open my $fh, '>',
      file($sql_dir, '_common', 'deploy', qw(_any 000-bar.sql ));
   print {$fh} 'INVALID SQL;';
   close $fh;

   like exception {
      $dm->deploy;
   }, qr(INVALID SQL), 'tried to run _any file when ignoring ddl';
}

done_testing;
#vim: ts=2 sw=2 expandtab
