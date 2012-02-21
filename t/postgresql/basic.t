#!/usr/bin/env perl

use warnings;
use strict;
use lib 't/lib';

use Test::More;
use Test::Requires qw(Test::postgresql);
use Test::Requires qw(POSIX);
use File::Spec::Functions 'catdir', 'catfile';
use File::Path 'remove_tree';
use DBIx::Class::DeploymentHandler;
use DBICDHTest;

ok my $testdb = build_test_postgresql(),
  'good test db';

my $dbh = DBI->connect("DBI:Pg:dbname=test;host=127.0.0.1;port=${\$testdb->port}",'postgres','');

VERSION1: {
  use_ok 'DBICVersion_v1';
  $DBICVersion::Schema::VERSION = 1;
  ok my $schema = DBICVersion::Schema->connect(sub { $dbh }),
    'got schema';

  ok my $dbic_dh = build_dh($schema),
    'got dbicdh';

  $dbic_dh->prepare_install;
  make_perl_runfile();
  $dbic_dh->install;

  is $dbic_dh->database_version, 1, 'correct db version';
}

VERSION2: {
  use_ok 'DBICVersion_v2';
  $DBICVersion::Schema::VERSION = 2;
  ok my $schema = DBICVersion::Schema->connect(sub { $dbh }),
    'got schema';

  ok my $dbic_dh = build_dh($schema,1),
    'got dbicdh';

  $dbic_dh->prepare_install();
  $dbic_dh->prepare_upgrade();
  $dbic_dh->prepare_downgrade();
}

ok -d catdir('t','share','var','pg-deploy','PostgreSQL','downgrade','2-1'),
  'reasonable defaults properly creates a downgrade';

$testdb->stop(POSIX::SIGINT);  ## We need this to stop Pg
done_testing();

sub build_dh {
  DBIx::Class::DeploymentHandler->new({
    script_directory => catdir('t','share','var','pg-deploy'),
    schema => shift,
    databases => ['PostgreSQL']});
}

sub build_test_postgresql {
  my %config = (
    base_dir => catdir('t','share','var','pg'),
    initdb_args => $Test::postgresql::Defaults{initdb_args},
    postmaster_args => $Test::postgresql::Defaults{postmaster_args});

  if(my $testdb = Test::postgresql->new(%config)) {
    return $testdb;
  } else {
    die $Test::postgresql::errstr;
  }
}

sub make_perl_runfile {
  open(
    my $perl_run,
    ">",
    catfile('t','share','var','pg-deploy','PostgreSQL', 'deploy', '1', '002-test.pl')
  ) || die "Cannot open: $!";

  print $perl_run <<'END';
  sub {
    my $schema = shift;
  };
END

  close $perl_run;
}

END {
  remove_tree catdir('t','share','var','pg');
  remove_tree catdir('t','share','var','pg-deploy');
}
