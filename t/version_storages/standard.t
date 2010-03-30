#!perl

use Test::More;
use Test::Deep;
use Test::Exception;

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::VersionStorage::Standard';
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';

use DBICVersion_v1;
use DBIx::Class::DeploymentHandler;
my $db = 'dbi:SQLite:db.db';
my @connection = ($db, '', '', { ignore_version => 1 });
my $sql_dir = 't/sql';

my $s = DBICVersion::Schema->connect(@connection);
{
	my $warning;
	local $SIG{__WARN__} = sub {$warning = shift};
	my $t = DBICVersion::Schema->connect('frewfrew', '', '');
	like( $warning, qr/Your DB is currently unversioned. Please call upgrade on your schema to sync the DB/, 'warning when database is unversioned');
}

DBICDHTest::ready;

my $dm = Translator->new({
	schema            => $s,
	upgrade_directory => $sql_dir,
	databases         => ['SQLite'],
	sqltargs          => { add_drop_table => 0 },
});

my $vs = Standard->new({ schema => $s });

$dm->prepare_resultsource_install(
	$vs->version_rs->result_source
);

ok( $vs, 'DBIC::DH::VersionStorage::Standard instantiates correctly' );

ok( !$vs->version_storage_is_installed, 'VersionStorage is not yet installed' );

$dm->install_resultsource(
	$vs->version_rs->result_source,
	'1.0',
);

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

{
	my $warning;
	local $SIG{__WARN__} = sub {$warning = shift};
	my $u = DBICVersion::Schema->connect($db, '', '');
	like( $warning, qr/Versions out of sync. This is 1.0, your database contains version 2.0, please call upgrade on your Schema./, 'warning when database/schema mismatch');
}


$vs->version_rs->delete;

ok( $vs->version_storage_is_installed, 'VersionStorage is still installed even if all versions are deleted' );
done_testing;
