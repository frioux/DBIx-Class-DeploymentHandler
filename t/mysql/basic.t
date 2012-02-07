#!/usr/bin/env perl

use warnings;
use strict;
use lib 't/lib';

use Test::More;
use Test::Requires qw(Test::postgresql);
use Test::Requires qw(Test::mysqld);
use File::Spec::Functions 'catdir', 'catfile';
use File::Path 'remove_tree';
use DBIx::Class::DeploymentHandler;
use DBICDHTest;


VERSION1: {
  ok my $testdb = build_test_mysql(),
    'good test db';

  my $dbh = DBI->connect("DBI:mysql:test;mysql_socket=${\$testdb->base_dir}/tmp/mysql.sock",'root','');

  use_ok 'DBICVersion_v1';
  $DBICVersion::Schema::VERSION = 1;
  ok my $schema = DBICVersion::Schema->connect(sub { $dbh }),
    'got schema';

  ok my $dbic_dh = build_dh($schema),
    'got dbicdh';

  $dbic_dh->prepare_install;
  $dbic_dh->install;

  is $dbic_dh->database_version, 1, 'correct db version';
}

VERSION2: {
  ok my $testdb = build_test_mysql(),
    'good test db';

  my $dbh = DBI->connect("DBI:mysql:test;mysql_socket=${\$testdb->base_dir}/tmp/mysql.sock",'root','');

  use_ok 'DBICVersion_v2';
  $DBICVersion::Schema::VERSION = 2;
  ok my $schema = DBICVersion::Schema->connect(sub { $dbh }),
    'got schema';

  ok my $dbic_dh = build_dh($schema,1),
    'got dbicdh';

  $dbic_dh->prepare_install();
  $dbic_dh->prepare_upgrade();
  $dbic_dh->prepare_downgrade();
  $dbic_dh->upgrade;

  is $dbic_dh->database_version, 2, 'correct db version';

}

ok -d catdir('t','share','var','mysql-deploy','MySQL','downgrade','2-1'),
  'reasonable defaults properly creates a downgrade';

VERSION1FORCE: {

  remove_tree catdir('t','share','var','mysql');

  ok my $testdb = build_test_mysql(),
    'good test db';

  my $dbh = DBI->connect("DBI:mysql:test;mysql_socket=${\$testdb->base_dir}/tmp/mysql.sock",'root','');

  use_ok 'DBICVersion_v2';
  $DBICVersion::Schema::VERSION = 2;
  ok my $schema = DBICVersion::Schema->connect(sub { $dbh }),
    'got schema';

  my $dbic_dh = DBIx::Class::DeploymentHandler->new({
    script_directory => catdir('t','share','var','mysql-deploy'),
    to_version => 1,
    schema => $schema,
    databases => ['MySQL']});

  $dbic_dh->install;

  is $dbic_dh->database_version, 1, 'correct db version';
}

done_testing();

sub build_dh {
  DBIx::Class::DeploymentHandler->new({
    script_directory => catdir('t','share','var','mysql-deploy'),
    schema => shift,
    databases => ['MySQL']});
}

sub build_test_mysql {
  my $base_dir = catdir('t','share','var','mysql');
  my $auto_start = -d $base_dir ? 1:2;
  my %config = (
    base_dir => $base_dir,
    auto_start => $auto_start);

  return Test::mysqld->new(
    auto_start => $auto_start,
    base_dir => $base_dir);


  if(my $testdb = Test::mysqld->new(%config)) {
    return $testdb;
  } else {
    die $Test::mysqld::errstr;
  }
}

END {
  remove_tree catdir('t','share','var','mysql');
  remove_tree catdir('t','share','var','mysql-deploy');
}

