package DBICVersion::Foo;

use utf8;
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
	baz => {
		data_type => 'VARCHAR',
		size => '10',
		is_nullable => 1,
	},
	biff => {
		data_type => 'VARCHAR',
		size => '10',
		is_nullable => 1,
	},
);

__PACKAGE__->set_primary_key('foo');


sub sqlt_deploy_hook {
  my( $self, $sqlt_table ) =  @_;

  $sqlt_table->schema->add_procedure(
    name => 'test_utf',
    parameters => [ name => '_string', type => 'text' ],
    extra => {
      returns => { type => 'VOID' },
      definitions => [
        { language => 'sql' },
        { quote    => '$$', body => 'SELECT "перевірка ЮТФ/check UTF"' },
      ]
    }
  );

  $sqlt_table->schema->add_trigger(
    name =>  'test_utf',
    perform_action_when =>  'before',
    database_events     =>  'update',
    on_table            =>  $sqlt_table->name,
    scope               =>  'row',
    action              =>  q!EXECUTE PROCEDURE test_utf("перевірка ЮТФ/check UTF")!
  );

}


package DBICVersion::Schema;
use base 'DBIx::Class::Schema';
use strict;
use warnings;

our $VERSION = '3.0';

__PACKAGE__->register_class('Foo', 'DBICVersion::Foo');
__PACKAGE__->load_components('DeploymentHandler::VersionStorage::Standard::Component');

1;
