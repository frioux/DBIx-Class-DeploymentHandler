#!perl

use Test::More;
use Test::Deep;
use Test::Exception;

use lib 't/lib';
use DBICDHTest;
use DBICTest;
use aliased 'DBIx::Class::DeploymentHandler::VersionStorage::Standard';

use DBICVersion_v1;
use DBIx::Class::DeploymentHandler;
my $db = 'dbi:SQLite:db.db';
my @connection = ($db, '', '', { ignore_version => 1 });
my $sql_dir = 't/sql';

my $s = DBICVersion::Schema->connect(@connection);
DBICDHTest::ready;

my $handler = DBIx::Class::DeploymentHandler->new({
	upgrade_directory => $sql_dir,
	schema => $s,
	databases => 'SQLite',
	sqltargs => { add_drop_table => 0 },
});

$handler->prepare_install();

my $vs = Standard->new({ schema => $s });

ok( $vs, 'DBIC::DH::VersionStorage::Standard instantiates correctly' );

ok( !$vs->version_storage_is_installed, 'VersionStorage is not yet installed' );

$handler->install();

ok( $vs->version_storage_is_installed, 'VersionStorage is now installed' );


cmp_deeply(
	[ map +{
		version     => $_->version,
		ddl         => $_->ddl,
		upgrade_sql => $_->upgrade_sql,
	}, $vs->version_rs->search(undef, {order_by => 'id'})->all],
	[{
		version     => '1.0',
		ddl         => undef,
		upgrade_sql => undef
	}],
	'initial version works correctly'
);

is( $vs->database_version, '1.0', 'database version is 1.0');
$vs->add_database_version({
	version => '2.0',
});
is( $vs->database_version, '2.0', 'database version is 2.0');

cmp_deeply(
	[ map +{
		version     => $_->version,
		ddl         => $_->ddl,
		upgrade_sql => $_->upgrade_sql,
	}, $vs->version_rs->search(undef, {order_by => 'id'})->all],
	[{
		version     => '1.0',
		ddl         => undef,
		upgrade_sql => undef
	},{
		version     => '2.0',
		ddl         => undef,
		upgrade_sql => undef
	}],
	'adding another version works correctly'
);

$vs->version_rs->delete;

ok( $vs->version_storage_is_installed, 'VersionStorage is still installed even if all versions are deleted' );
done_testing;
