package DBICVersionAlt::Foo;

use base 'DBIx::Class::Core';
use strict;
use warnings;

__PACKAGE__->table('FooAlt');

__PACKAGE__->add_columns(
   foo => {
      data_type => 'INTEGER',
      is_auto_increment => 1,
   },
   bar => {
      data_type => 'VARCHAR',
      size => '10'
   },
);

__PACKAGE__->set_primary_key('foo');

package DBICVersionAlt::Version;
use base 'DBIx::Class::DeploymentHandler::VersionStorage::Standard::VersionResult';
use strict;
use warnings;

__PACKAGE__->table('dbic_version');

package DBICVersionAlt::Schema;
use base 'DBIx::Class::Schema';
use strict;
use warnings;

our $VERSION = '1.0';

__PACKAGE__->register_class('Foo', 'DBICVersionAlt::Foo');

1;
