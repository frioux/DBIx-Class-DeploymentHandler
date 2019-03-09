use strict;
use warnings;

use Test::More;

use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator;

sub make_dm {
  my ($storage_class) = @_;
  bless {
  }, 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
}

my $dm = make_dm();

is_deeply [ $dm->_split_sql_chunk( <<'END' ) ], [ 'SELECT * FROM YADAH END' ];
BEGIN
    -- stuff
    SELECT * FROM YADAH
END;
END

is_deeply [ $dm->_split_sql_chunk( 'foo', ' ', 'bar' ) ], [qw(foo bar)];

done_testing;
