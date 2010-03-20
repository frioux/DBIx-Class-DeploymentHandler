package DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResult;

use strict;
use warnings;

use parent 'DBIx::Class::Core';

__PACKAGE__->table('dbix_class_deploymenthandler_versions');

__PACKAGE__->add_columns (
  installed => {
    data_type         => 'int',
    is_auto_increment => 1,
  },
  version => {
    data_type         => 'varchar',
    # size needs to be at least
    # 40 to support SHA1 versions
    size              => '50'
  },
  ddl => {
    data_type         => 'text',
    is_nullable       => 1,
  },
  upgrade_sql => {
    data_type         => 'text',
    is_nullable       => 1,
  },
);

__PACKAGE__->set_primary_key('installed');
__PACKAGE__->add_unique_constraint(['version']);
__PACKAGE__->resultset_class('DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResultSet');

1;
