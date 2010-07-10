#!perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use lib 't/lib';
use aliased
  'DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions';

my $versions = [map "$_.0", 0..100];

{
  my $vh = ExplicitVersions->new({
    ordered_versions => $versions,
    schema_version => '2.0',
    database_version => '1.0',
  });

  ok $vh, 'VersionHandler gets instantiated';

  ok(
    eq_array($vh->next_version_set, [qw( 1.0 2.0 )]),
    'first version pair works'
  );
  ok(
    !$vh->next_version_set,
    'next version set returns undef when we are done'
  );
}

{
  my $vh = ExplicitVersions->new({
    ordered_versions => $versions,
    to_version => '1.0',
    schema_version => '1.0',
    database_version => '1.0',
  });

  ok $vh, 'VersionHandler gets instantiated';

  ok(
    !$vh->next_version_set,
    'next version set returns undef if we are at the version requested'
  );
}

{
  my $vh = ExplicitVersions->new({
    ordered_versions => $versions,
    to_version => '5.0',
    schema_version => '1.0',
    database_version => '1.0',
  });

  ok $vh, 'VersionHandler gets instantiated';
  ok(
    eq_array($vh->next_version_set, [qw( 1.0 2.0 )]),
    'first version pair works'
  );
  ok(
    eq_array($vh->next_version_set, [qw( 2.0 3.0 )]),
    'second version pair works'
  );
  ok(
    eq_array($vh->next_version_set, [qw( 3.0 4.0 )]),
    'third version pair works'
  );
  ok(
    eq_array($vh->next_version_set, [qw( 4.0 5.0 )]),
    'fourth version pair works'
  );
  ok( !$vh->next_version_set, 'no more versions after final pair' );
  ok( !$vh->next_version_set, 'still no more versions after final pair' );
}

{
  my $vh = ExplicitVersions->new({
    ordered_versions => $versions,
    to_version => '1.0',
    schema_version => '5.0',
    database_version => '5.0',
  });

  ok $vh, 'VersionHandler gets instantiated';
  ok(
    eq_array($vh->previous_version_set, [qw( 5.0 4.0 )]),
    'first version pair works'
  );
  ok(
    eq_array($vh->previous_version_set, [qw( 4.0 3.0 )]),
    'second version pair works'
  );
  ok(
    eq_array($vh->previous_version_set, [qw( 3.0 2.0 )]),
    'third version pair works'
  );
  ok(
    eq_array($vh->previous_version_set, [qw( 2.0 1.0 )]),
    'fourth version pair works'
  );
  ok( !$vh->previous_version_set, 'no more versions after final pair' );
  ok( !$vh->previous_version_set, 'still no more versions after final pair' );
}

dies_ok {
  my $vh = ExplicitVersions->new({
    ordered_versions => $versions,
    schema_version => '2.0',
    database_version => '1.1',
  });
  $vh->next_version_set
} 'dies if database version not found in ordered_versions';

dies_ok {
  my $vh = ExplicitVersions->new({
    ordered_versions => $versions,
    to_version => '0.0',
    schema_version => '1.0',
    database_version => '1.0',
  });
  $vh->next_version_set;
} 'cannot request an upgrade before the current version';

dies_ok {
  my $vh = ExplicitVersions->new({
    ordered_versions => $versions,
    to_version => '2.0',
    schema_version => '1.0',
    database_version => '1.0',
  });
  $vh->previous_version_set;
} 'cannot request a downgrade after the current version';

done_testing;
#vim: ts=2 sw=2 expandtab
