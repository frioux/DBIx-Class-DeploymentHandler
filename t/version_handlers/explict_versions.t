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

my $versions = [map "$_.0", 0..100];

{
  my $vh = DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions->new({
    schema => $s,
    ordered_versions => $versions,
    to_version => '1.0',
    version_storage => $v_storage,
  });

  ok $vh, 'VersionHandler gets instantiated';

  ok( !$vh->next_version_set, 'next version set returns undef if we are at the version requested' );
}

{
  my $vh = DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions->new({
    schema => $s,
    ordered_versions => $versions,
    to_version => '5.0',
    version_storage => $v_storage,
  });

  ok $vh, 'VersionHandler gets instantiated';
  ok( eq_array($vh->next_version_set, [qw( 1.0 2.0 )]), 'first version pair works' );
  ok( eq_array($vh->next_version_set, [qw( 2.0 3.0 )]), 'second version pair works' );
  ok( eq_array($vh->next_version_set, [qw( 3.0 4.0 )]), 'third version pair works' );
  ok( eq_array($vh->next_version_set, [qw( 4.0 5.0 )]), 'fourth version pair works' );
  ok( !$vh->next_version_set, 'no more versions after final pair' );
  ok( !$vh->next_version_set, 'still no more versions after final pair' );
}

dies_ok {
  my $vh = DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions->new({
    schema => $s,
    ordered_versions => $versions,
    to_version => '0.0',
    version_storage => $v_storage,
  });
} 'cannot request a version before the current version';

done_testing;
__END__

vim: ts=2 sw=2 expandtab
