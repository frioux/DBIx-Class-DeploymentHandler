use strict;
use warnings;

use Test::More tests => 2;

use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator;

*split_sql_chunk =
*DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::_split_sql_chunk;

is_deeply [ split_sql_chunk( <<'END' ) ], [ 'SELECT * FROM YADAH END' ];
BEGIN
    -- stuff
    SELECT * FROM YADAH
END;
END

is_deeply [ split_sql_chunk( <<'END' ) ], [ 'CREATE VIEW `view1` ( `col1` ) AS SELECT cola FROM shop END' ];

--
-- View: `view1`
--
CREATE
  VIEW `view1` ( `col1` ) AS

SELECT
  cola
 FROM
 shop



;

END

