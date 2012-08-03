#!perl

use strict;
use warnings;

use Test::More;

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::VersionStorage::Standard';
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
use File::Temp 'tempdir';

use DBICVersion_v1;
use DBIx::Class::DeploymentHandler;
my $dbh = DBICDHTest::dbh();
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = tempdir( CLEANUP => 1 );

my $s = DBICVersion::Schema->connect(@connection);
{
   my $warning;
   local $SIG{__WARN__} = sub {$warning = shift};
   my $t = DBICVersion::Schema->connect('frewfrew', '', '');
   like( $warning, qr/Your DB is currently unversioned. Please call upgrade on your schema to sync the DB/, 'warning when database is unversioned');
}

my $dm = Translator->new({
   schema            => $s,
   script_directory => $sql_dir,
   databases         => ['SQLite'],
   sql_translator_args          => { add_drop_table => 0 },
});

my $vs = Standard->new({ schema => $s });

$dm->prepare_resultsource_install({
   result_source => $vs->version_rs->result_source
});

ok( $vs, 'DBIC::DH::VersionStorage::Standard instantiates correctly' );

ok( !$vs->version_storage_is_installed, 'VersionStorage is not yet installed' );

$dm->install_resultsource({
   result_source => $vs->version_rs->result_source,
   version => '1.0',
});

ok( $vs->version_storage_is_installed, 'VersionStorage is now installed' );


$vs->add_database_version({
   version => '1.0',
});

ok(
   eq_array(
      [ $vs->version_rs->search(undef, {order_by => 'id'})->get_column('version')->all],
      [ '1.0' ],
   ),
   'initial version works correctly'
);

is( $vs->database_version, '1.0', 'database version is 1.0');
$vs->add_database_version({
   version => '2.0',
});
is( $vs->database_version, '2.0', 'database version is 2.0');

ok(
   eq_array(
      [ $vs->version_rs->search(undef, {order_by => 'id'})->get_column('version')->all],
      [ '1.0', '2.0', ],
   ),
   'adding another version works correctly'
);

my $u;
{
   my $warning;
   local $SIG{__WARN__} = sub {$warning = shift};
   $u = DBICVersion::Schema->connect(sub { $dbh });
   like( $warning, qr/Versions out of sync. This is 1\.0, your database contains version 2\.0, please call upgrade on your Schema\./, 'warning when database/schema mismatch');
}


$vs->version_rs->delete;

ok( $vs->version_storage_is_installed, 'VersionStorage is still installed even if all versions are deleted' );
done_testing;
