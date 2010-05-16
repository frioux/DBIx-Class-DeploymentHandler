package DBICVersion::Foo;

use base 'DBIx::Class::Core';
use strict;
use warnings;

__PACKAGE__->table('Foo');

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

package DBICVersion::Schema;
use base 'DBIx::Class::Schema';
use strict;
use warnings;

our $VERSION = '1.0';

__PACKAGE__->register_class('Foo', 'DBICVersion::Foo');

1;
