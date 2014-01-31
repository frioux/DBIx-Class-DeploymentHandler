#!perl

use strict;
use warnings;

use Test::More;

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
use IO::All;
use File::Temp qw(tempfile tempdir);

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

   $dm->prepare_deploy;
   $dm->deploy;
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

   $dm->prepare_deploy;
   io->dir($sql_dir, qw(_preprocess_schema upgrade 1.0-2.0 ))->mkpath;
   open my $prerun, '>',
      io->file($sql_dir, qw(_preprocess_schema upgrade 1.0-2.0 003-semiautomatic.pl )) . "";
   my (undef, $fn) = tempfile(OPEN => 0);
   print {$prerun}
      qq^sub {
         open my \$fh, ">", '$fn'
            if \$_[0]->isa("SQL::Translator::Schema")
            && \$_[1]->isa("SQL::Translator::Schema");
      }^;
   close $prerun;
   $dm->prepare_upgrade({
     from_version => '1.0',
     to_version => '2.0',
     version_set => [qw(1.0 2.0)]
   });
   ok -e $fn, 'intermediate script ran with the right args';
   $dm->upgrade_single_step({ version_set => [qw( 1.0 2.0 )] });
}
done_testing;
#vim: ts=2 sw=2 expandtab
