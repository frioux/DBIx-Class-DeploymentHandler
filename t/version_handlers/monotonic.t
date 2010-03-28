#!perl

use Test::More;
use Test::Exception;

use lib 't/lib';
use aliased
  'DBIx::Class::DeploymentHandler::VersionHandler::Monotonic';

{
  my $vh = Monotonic->new({
    schema_version   => 2,
    database_version => 1,
  });

  ok $vh, 'VersionHandler gets instantiated';

  ok(
    eq_array($vh->next_version_set, [1,2]),
    'first version pair works'
  );
  ok(
    !$vh->next_version_set,
    'next version set returns undef when we are done'
  );
}

{
  my $vh = Monotonic->new({
	 to_version       => 1,
	 schema_version   => 1,
	 database_version => 1,
  });

  ok $vh, 'VersionHandler gets instantiated';

  ok(
	 !$vh->next_version_set,
	 'next version set returns undef if we are at the version requested'
  );
}

ONETOFIVE: {
  my $vh = Monotonic->new({
	 to_version       => 5,
	 schema_version   => 1,
	 database_version => 1,
  });

  ok $vh, 'VersionHandler gets instantiated';
  ok(
	 eq_array($vh->next_version_set, [1,2]),
	 'first version pair works'
  );
  ok(
	 eq_array($vh->next_version_set, [2,3]),
	 'second version pair works'
  );
  ok(
	 eq_array($vh->next_version_set, [3,4]),
	 'third version pair works'
  );
  ok(
	 eq_array($vh->next_version_set, [4,5]),
	 'fourth version pair works'
  );
  ok( !$vh->next_version_set, 'no more versions after final pair' );
  ok( !$vh->next_version_set, 'still no more versions after final pair' );
}

FIVETOONE: {
  my $vh = Monotonic->new({
	 to_version       => 1,
	 schema_version   => 1,
	 database_version => 5,
  });

  ok $vh, 'VersionHandler gets instantiated';
  ok(
	 eq_array($vh->previous_version_set, [4,5]),
	 'first version pair works'
  );
  ok(
	 eq_array($vh->previous_version_set, [3,4]),
	 'second version pair works'
  );
  ok(
	 eq_array($vh->previous_version_set, [2,3]),
	 'third version pair works'
  );
  ok(
	 eq_array($vh->previous_version_set, [1,2]),
	 'fourth version pair works'
  );
  ok( !$vh->previous_version_set, 'no more versions before initial pair' );
  ok( !$vh->previous_version_set, 'still no more versions before initial pair' );
}

dies_ok {
  my $vh = Monotonic->new({
	 schema_version   => 2,
	 database_version => '1.1',
  });
  $vh->next_version_set
} 'dies if database version not an Int';

dies_ok {
  my $vh = Monotonic->new({
	 to_version       => 0,
	 schema_version   => 1,
	 database_version => 1,
  });
  $vh->next_version_set;
} 'cannot request an upgrade version before the current version';

dies_ok {
  my $vh = Monotonic->new({
	 to_version       => 2,
	 schema_version   => 1,
	 database_version => 1,
  });
  $vh->previous_version_set;
} 'cannot request a downgrade version after the current version';

done_testing;
#vim: ts=2 sw=2 expandtab
