use strict;
use warnings;

use Test::More tests => 1;

use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator;

*split_sql_chunk =
*DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::_split_sql_chunk;

is_deeply [ split_sql_chunk( <<'END' ) ], [ 'SELECT * FROM YADAH END' ];
BEGIN
    -- stuff
    SELECT * FROM YADAH
END;
END

