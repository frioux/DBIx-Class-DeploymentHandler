use strict;
use warnings;

use version;
use Test::More;
use_ok("DBIx::Class::DeploymentHandler::Dad");

subtest "schema version object", sub {
    my $v = "0.1";
    {

        package Foo;
        $Foo::VERSION = version->parse($v);
        sub schema_version {$Foo::VERSION}
        1;
    }

    my $c = new_ok("DBIx::Class::DeploymentHandler::Dad", [schema => "Foo"]);
    is($c->schema_version, $v);
};

subtest "schema version string", sub {
    my $v = "0.2";
    {

        package Bar;
        $Bar::VERSION = $v;
        sub schema_version {$Bar::VERSION}
        1;
    }

    my $c = new_ok("DBIx::Class::DeploymentHandler::Dad", [schema => "Bar"]);
    is($c->schema_version, $v);
};

done_testing();
