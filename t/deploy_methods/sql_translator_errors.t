#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal qw(dies_ok exception);

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
use IO::All;
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

   my $initdir = io->dir($sql_dir, qw(SQLite initialize 1.0));
   $initdir->mkpath;
   run_file($dm, 'initialize', $initdir, '000-bad.pl',
     'INVALID PERL";',
     qr(failed to compile),
     'initialize parse error',
   );

   my $dir = io->dir($sql_dir, qw(SQLite deploy 1.0));
   $dir->mkpath;

   run_file($dm, 'deploy', $dir, '000-foo.pl',
     'sub {die "test"}',
     qr(Perl in .*SQLite.*deploy.*1\.0.*000-foo\.pl),
     'file prepended to Perl script error',
   );

   run_file($dm, 'deploy', $dir, '000-bar.sql',
     'INVALID SQL;',
     qr(SQL in .*SQLite.*deploy.*1\.0.*000-bar\.sql),
     'file prepended to SQL script error',
   );

   run_file($dm, 'deploy', $dir, '000-baz.pl',
     'INVALID PERL";',
     qr(find string terminator),
     'non-perl or SQL file',
   );

   run_file($dm, 'deploy', $dir, '000-bae.pl',
     '"just a string"',
     qr(should define an anonymous sub),
     'non-function',
   );
}

sub run_file {
  my ($dm, $method, $dir, $name, $content, $re, $label) = @_;
  my $file = $dir->catfile($name);
  $file->print($content);
  $file->close;
  like exception {
    $dm->$method;
  }, $re, $label;
  unlink "$file";
}

done_testing;
#vim: ts=2 sw=2 expandtab
