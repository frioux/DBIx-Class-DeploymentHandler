#!perl

use strict;
use warnings;

use lib 't/lib';
use DBICDHTest;
use DBIx::Class::DeploymentHandler;
use aliased 'DBIx::Class::DeploymentHandler', 'DH';

use IO::All;
use Test::More;
use File::Temp 'tempdir';

my $db = 'dbi:SQLite::memory:';
my @connection = ($db, '', '', { ignore_version => 1, on_connect_do => sub { die }});
my $sql_dir = tempdir( CLEANUP => 1 );

VERSION1: {
  use_ok 'DBICVersion_v1';
  my $s = DBICVersion::Schema->connect(@connection);
  $DBICVersion::Schema::VERSION = 1;
  ok($s, 'DBICVersion::Schema 1 instantiates correctly');
  ok !$s->storage->connected, 'creating schema did not connect';
  my $handler = DH->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
    sql_translator_args => { add_drop_table => 0 },
  });
  ok !$s->storage->connected, 'creating handler did not connect';
  ok($handler, 'DBIx::Class::DeploymentHandler w/1 instantiates correctly');

  io->dir($sql_dir, qw(SQLite initialize 1))->mkpath;
  $handler->initialize({ version => 1, storage_type => 'SQLite' });
  ok !$s->storage->connected, 'creating schema did not connect';
}
done_testing;
