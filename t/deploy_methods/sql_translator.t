#!perl

use Test::More;
use Test::Exception;

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';

my $db = 'dbi:SQLite:db.db';
my @connection = ($db, '', '', { ignore_version => 1 });
my $sql_dir = 't/sql';

DBICDHTest::ready;

VERSION1: {
   use_ok 'DBICVersion_v1';
   my $s = DBICVersion::Schema->connect(@connection);
   my $dm = Translator->new({
      schema => $s,
      upgrade_directory => $sql_dir,
      databases => ['SQLite'],
   });

   ok( $dm, 'DBIC::DH::DM::SQL::Translator gets instantiated correctly' );
}

done_testing;
