#!perl

use Test::More;
use Test::Exception;

use lib 't/lib';
use DBICDHTest;
use DBICTest;
use DBIx::Class::DeploymentHandler;
use DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions;
my $db = 'dbi:SQLite:db.db';
my @connection = ($db, '', '', { ignore_version => 1 });
my $sql_dir = 't/sql';

DBICDHTest::ready;

use DBICVersion_v1;
my $s = DBICVersion::Schema->connect(@connection);

my $handler = DBIx::Class::DeploymentHandler->new({
   upgrade_directory => $sql_dir,
   schema => $s,
   databases => 'SQLite',
 sqltargs => { add_drop_table => 0 },
});
my $v_storage = $handler->version_storage;
my $version = $s->schema_version();
$handler->prepare_install();

$handler->install;
{
  my $vh = DBIx::Class::DeploymentHandler::VersionHandler::DatabaseToSchemaVersions->new({
    schema => $s,
    ordered_versions => $versions,
    to_version => '5.0',
    version_storage => $v_storage,
  });

  ok( $vh, 'VersionHandler gets instantiated' );
  ok( eq_array( $vh->next_version_set, [qw( 1.0 5.0 )] ), 'db version and to_version get correctly put into version set');
  ok( !$vh->next_version_set, 'next_version_set only works once');
  ok( !$vh->next_version_set, 'seriously.');
}

{
  my $vh = DBIx::Class::DeploymentHandler::VersionHandler::DatabaseToSchemaVersions->new({
    schema => $s,
    ordered_versions => $versions,
    version_storage => $v_storage,
  });

  ok( $vh, 'VersionHandler gets instantiated' );
  ok( !$vh->next_version_set, 'VersionHandler is null when schema_version and db_verison are the same' );
}

{
  my $vh = DBIx::Class::DeploymentHandler::VersionHandler::DatabaseToSchemaVersions->new({
    schema => $s,
    ordered_versions => $versions,
    version_storage => $v_storage,
  });

  ok( $vh, 'VersionHandler gets instantiated' );
  ok( !$vh->next_version_set, 'VersionHandler is null when schema_version and db_verison are the same' );
}

{
  $DBICVersion::Schema::VERSION = '10.0';

  my $vh = DBIx::Class::DeploymentHandler::VersionHandler::DatabaseToSchemaVersions->new({
    schema => $s,
    ordered_versions => $versions,
    version_storage => $v_storage,
  });

  ok( $vh, 'VersionHandler gets instantiated' );
  ok( eq_array( $vh->next_version_set, [qw( 1.0 10.0 )] ), 'db version and schema version get correctly put into version set');
  ok( !$vh->next_version_set, 'VersionHandler is null on next try' );
}

done_testing;
__END__

vim: ts=2 sw=2 expandtab
