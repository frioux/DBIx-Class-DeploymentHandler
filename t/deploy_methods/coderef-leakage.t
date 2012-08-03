#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal qw(lives_ok dies_ok);
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
use File::Temp 'tempdir';

use lib 't/lib';

use DBICDHTest;

my $dbh = DBICDHTest::dbh();
my $sql_dir = tempdir( CLEANUP => 1 );
my @connection = (sub { $dbh }, { ignore_version => 1 });

use_ok 'DBICVersion_v1';
my $s = DBICVersion::Schema->connect(@connection);
my $dm = Translator->new({
   schema => $s,
   script_directory => $sql_dir,
});

my ($fname1, $fname2) = @_;

{
   my $fh = File::Temp->new(UNLINK => 0);
   print {$fh} 'sub leak {} sub { leak() }';
   $fname1 = $fh->filename;
   close $fh;
}

{
   my $fh = File::Temp->new(UNLINK => 0);
   print {$fh} 'sub { leak() }';
   $fname2 = $fh->filename;
   close $fh;
}

$dm->_run_perl($fname1, [1]);
dies_ok { $dm->_run_perl($fname2, [1]) } 'info should not leak between coderefs';

done_testing;

END { unlink $fname1; unlink $fname2 }
