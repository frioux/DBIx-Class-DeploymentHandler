use strict;
use warnings;

use Test::More;

use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator;

sub make_dm {
  my ($storage_class) = @_;
  bless {
    storage => bless({}, 'DBIx::Class::Storage::DBI::'.$storage_class),
  }, 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
}

my $dm = make_dm('MySQL');

is_deeply [ $dm->_split_sql_chunk( <<'END' ) ], [ 'SELECT * FROM YADAH END' ];
BEGIN
    -- stuff
    SELECT * FROM YADAH
END;
END

is_deeply [ $dm->_split_sql_chunk( 'foo', ' ', 'bar' ) ], [qw(foo bar)];

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
  [ q{CREATE FUNCTION add_rating() RETURNS trigger AS $add_rating$ IF NEW."type" = 'like' THEN UPDATE "list_materials" SET "likes" = (SELECT COUNT(*) FROM "list_material_ratings" WHERE "list" = NEW."list" AND "material" = NEW."material" AND "type" = 'like') WHERE "list" = NEW."list" AND "material" = NEW."material"; END IF; IF NEW."type" = 'dislike' THEN UPDATE "list_materials" SET "dislikes" = (SELECT COUNT(*) FROM "list_material_ratings" WHERE "list" = NEW."list" AND "material" = NEW."material" AND "type" = 'dislike') WHERE "list" = NEW."list" AND "material" = NEW."material"; END IF; RETURN NULL; END; $add_rating$ LANGUAGE plpgsql} ];

$dm = make_dm('Pg');
is_deeply [ $dm->_split_sql_chunk( <<'END' ) ],
CREATE TABLE "dbix_class_deploymenthandler_versions" ( "id" serial NOT NULL, "version" character varying(50) NOT NULL, "ddl" text, "upgrade_sql" text, PRIMARY KEY ("id"), CONSTRAINT "dbix_class_deploymenthandler_versions_version" UNIQUE ("version") )
END
  [ q{CREATE TABLE "dbix_class_deploymenthandler_versions" ( "id" serial NOT NULL, "version" character varying(50) NOT NULL, "ddl" text, "upgrade_sql" text, PRIMARY KEY ("id"), CONSTRAINT "dbix_class_deploymenthandler_versions_version" UNIQUE ("version") )} ];

done_testing;
