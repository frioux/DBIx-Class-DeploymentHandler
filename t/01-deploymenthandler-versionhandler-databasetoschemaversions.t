#!perl

use strict;
use warnings;
use version;
use Test::More;

my $m
    = "DBIx::Class::DeploymentHandler::VersionHandler::DatabaseToSchemaVersions";
use_ok($m);

subtest "$m version object", sub {
    my $v = qv("1.0");
    my $c = new_ok(
        $m,
        [
            to_version       => "$v",
            database_version => "$v",
            schema_version   => $v,
        ]
    );
    is($c->schema_version, $v);
};

subtest "$m version string", sub {
    my $v = "0.1";
    my $c = new_ok(
        $m,
        [
            to_version       => $v,
            database_version => $v,
            schema_version   => $v,
        ]
    );
    is($c->schema_version, $v);
};

done_testing();
