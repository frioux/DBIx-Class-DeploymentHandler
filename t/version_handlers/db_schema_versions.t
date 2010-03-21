#!perl

use Test::More;
use Test::Exception;

use lib 't/lib';
use aliased
  'DBIx::Class::DeploymentHandler::VersionHandler::DatabaseToSchemaVersions';

{
  my $vh = DatabaseToSchemaVersions->new({
    to_version => '5.0',
    database_version => '1.0',
    schema_version => '1.0',
  });

  ok( $vh, 'VersionHandler gets instantiated' );
  ok(
    eq_array( $vh->next_version_set, [qw( 1.0 5.0 )] ),
    'db version and to_version get correctly put into version set'
  );
  ok( !$vh->next_version_set, 'next_version_set only works once');
  ok( !$vh->next_version_set, 'seriously.');
}

{
  my $vh = DatabaseToSchemaVersions->new({
    database_version => '1.0',
    schema_version => '1.0',
  });

  ok( $vh, 'VersionHandler gets instantiated' );
  ok(
    !$vh->next_version_set,
    'VersionHandler is null when schema_version and db_verison are the same'
  );
}

{
  my $vh = DatabaseToSchemaVersions->new({
    database_version => '1.0',
    schema_version => '1.0',
  });

  ok( $vh, 'VersionHandler gets instantiated' );
  ok(
    !$vh->next_version_set,
    'VersionHandler is null when schema_version and db_verison are the same'
  );
}

{
  my $vh = DatabaseToSchemaVersions->new({
    database_version => '1.0',
    schema_version => '10.0',
  });

  ok( $vh, 'VersionHandler gets instantiated' );
  ok(
    eq_array( $vh->next_version_set, [qw( 1.0 10.0 )] ),
    'db version and schema version get correctly put into version set'
  );
  ok( !$vh->next_version_set, 'VersionHandler is null on next try' );
}

done_testing;
# vim: ts=2 sw=2 expandtab
