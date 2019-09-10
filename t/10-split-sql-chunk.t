use strict;
use warnings;
use 5.010;

use Test::More;

use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator;

sub make_dm {
  my $storage_class = shift;
  bless {
    storage => bless({}, 'DBIx::Class::Storage::DBI::'.$storage_class),
    @_,
  }, 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
}

my $dm = make_dm('MySQL');

is_deeply [ $dm->_split_sql_chunk( <<'END' ) ], [ 'BEGIN SELECT * FROM YADAH END' ];
BEGIN
    -- stuff
    SELECT * FROM YADAH
END;
END

is_deeply [ $dm->_split_sql_chunk( 'foo', ' ', 'bar' ) ], [qw(foo bar)];

$dm = make_dm('MySQL', txn_prep => 1);  # default, bw-comp.

is_deeply [ $dm->_split_sql_chunk( <<'END' ) ],
BEGIN;
-- stuff
DELIMITER $$
insert into door (color) VALUES ('#f00')$$
SELECT * FROM YADAH$$
DELIMITER ;
Commit;
END
  [
    q(insert into door (color) VALUES ('#f00')),
    'SELECT * FROM YADAH',
  ];

$dm = make_dm('MySQL', txn_prep => 0);

is_deeply [ $dm->_split_sql_chunk( <<'END' ) ],
BEGIN;
-- stuff
DELIMITER $$
insert into door (color) VALUES ('#000')$$
SELECT * FROM YADAH$$
DELIMITER ;
Commit;
END
  [
    'BEGIN',
    q(insert into door (color) VALUES ('#000')),
    'SELECT * FROM YADAH',
    'Commit',
  ];

$dm = make_dm('MySQL', txn_prep => 0);

is_deeply [ $dm->_split_sql_chunk( <<'END' ) ],
insert into door (color) VALUES ('#000');

CREATE TRIGGER upd_check BEFORE UPDATE ON account
     FOR EACH ROW
     BEGIN
         IF NEW.amount < 0 THEN
             SET NEW.amount = 0;
         ELSEIF NEW.amount > 100 THEN
             SET NEW.amount = 100;
         END IF;
     END;

SELECT * FROM YADAH;

END
  [
    q(insert into door (color) VALUES ('#000')),
    'CREATE TRIGGER upd_check BEFORE UPDATE ON account FOR EACH ROW BEGIN IF NEW.amount < 0 THEN SET NEW.amount = 0; ELSEIF NEW.amount > 100 THEN SET NEW.amount = 100; END IF; END',
    'SELECT * FROM YADAH',
  ];


$dm = make_dm('Pg');
is_deeply [ $dm->_split_sql_chunk( <<'END' ) ],
-- Add triggers to maintain sync between list_material_ratings table and list_materials table:;
CREATE FUNCTION add_rating() RETURNS trigger AS $add_rating$
 BEGIN
  IF NEW."type" = 'like' THEN
    UPDATE "list_materials" SET "likes" = (SELECT COUNT(*) FROM "list_material_ratings" WHERE "list" = NEW."list" AND "material" = NEW."material" AND "type" = 'like') WHERE "list" = NEW."list" AND "material" = NEW."material";
  END IF;
  IF NEW."type" = 'dislike' THEN
    UPDATE "list_materials" SET "dislikes" = (SELECT COUNT(*) FROM "list_material_ratings" WHERE "list" = NEW."list" AND "material" = NEW."material" AND "type" = 'dislike') WHERE "list" = NEW."list" AND "material" = NEW."material";
  END IF;
  RETURN NULL;
 END;
$add_rating$ LANGUAGE plpgsql;
END
  [ q{CREATE FUNCTION add_rating() RETURNS trigger AS $add_rating$ BEGIN IF NEW."type" = 'like' THEN UPDATE "list_materials" SET "likes" = (SELECT COUNT(*) FROM "list_material_ratings" WHERE "list" = NEW."list" AND "material" = NEW."material" AND "type" = 'like') WHERE "list" = NEW."list" AND "material" = NEW."material"; END IF; IF NEW."type" = 'dislike' THEN UPDATE "list_materials" SET "dislikes" = (SELECT COUNT(*) FROM "list_material_ratings" WHERE "list" = NEW."list" AND "material" = NEW."material" AND "type" = 'dislike') WHERE "list" = NEW."list" AND "material" = NEW."material"; END IF; RETURN NULL; END; $add_rating$ LANGUAGE plpgsql} ];

$dm = make_dm('Pg');
is_deeply [ $dm->_split_sql_chunk( <<'END' ) ],
CREATE TABLE "dbix_class_deploymenthandler_versions" ( "id" serial NOT NULL, "version" character varying(50) NOT NULL, "ddl" text, "upgrade_sql" text, PRIMARY KEY ("id"), CONSTRAINT "dbix_class_deploymenthandler_versions_version" UNIQUE ("version") )
END
  [ q{CREATE TABLE "dbix_class_deploymenthandler_versions" ( "id" serial NOT NULL, "version" character varying(50) NOT NULL, "ddl" text, "upgrade_sql" text, PRIMARY KEY ("id"), CONSTRAINT "dbix_class_deploymenthandler_versions_version" UNIQUE ("version") )} ];

done_testing;
