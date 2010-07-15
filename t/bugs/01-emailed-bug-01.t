#!perl

use strict;
use warnings;

use lib 't/lib';
use DBICDHTest;
use DBIx::Class::DeploymentHandler;
use aliased 'DBIx::Class::DeploymentHandler', 'DH';

use File::Path 'remove_tree';
use Test::More;
use Test::Exception;

DBICDHTest::ready;

my $dbh = DBI->connect('dbi:SQLite::memory:');
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = 't/sql';

use_ok 'DBICVersion_v1';
my $s = DBICVersion::Schema->connect(@connection);
$DBICVersion::Schema::VERSION = 1;
ok($s, 'DBICVersion::Schema 1 instantiates correctly');

my $dh = DH->new({
  script_directory => $sql_dir,
  schema => $s,
  databases => 'SQLite',
  sql_translator_args => { add_drop_table => 0 },
});

ok($dh, 'DBIx::Class::DeploymentHandler w/1 instantiates correctly');
$dh->prepare_version_storage_install;


dies_ok { $s->resultset('__VERSION')->first->version } 'version_storage not installed';
$dh->install_version_storage;

$dh->add_database_version( { version => $s->schema_version } );

lives_ok { $s->resultset('__VERSION')->first->version } 'version_storage installed';

done_testing;
