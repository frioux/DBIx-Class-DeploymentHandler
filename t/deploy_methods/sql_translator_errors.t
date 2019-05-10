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
   });

   ok( $dm, 'DBIC::DH::DM::SQL::Translator gets instantiated correctly' );

   my $lethal_perl = file($sql_dir, 'SQLite', 'deploy', qw(1.0 000-foo.pl ));
   dir($sql_dir, 'SQLite',  'deploy', '1.0')->mkpath;
   {
      open my $fh, '>', $lethal_perl;
      print {$fh} 'sub {die "test"}';
      close $fh;
   }

   like exception {
      $dm->deploy;
   }, qr(Perl in .*SQLite[/\\]deploy[/\\]1\.0[/\\]000-foo\.pl), 'file prepended to Perl script error';

   unlink "$lethal_perl";

   open my $fh, '>',
      file($sql_dir, 'SQLite', 'deploy', qw(1.0 000-bar.sql ));
   print {$fh} 'INVALID SQL;';
   close $fh;

   like exception {
      $dm->deploy;
   }, qr(SQL in .*SQLite[/\\]deploy[/\\]1\.0[/\\]000-bar\.sql), 'file prepended to SQL script error';
}

done_testing;
#vim: ts=2 sw=2 expandtab
