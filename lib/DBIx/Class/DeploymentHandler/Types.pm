package DBIx::Class::DeploymentHandler::Types;

use strict;
use warnings;

# ABSTRACT: Types internal to DBIx::Class::DeploymentHandler

use Type::Library
  -base,
  -declare => qw( Databases VersionNonObj );
use Type::Utils -all;
BEGIN { extends "Types::Standard" };

declare Databases, as ArrayRef[Str];

coerce Databases,
  from Str, via { [ $_ ] };

declare VersionNonObj, as Str;

coerce VersionNonObj,
  from InstanceOf['version'], via { $_->numify };

1;

# vim: ts=2 sw=2 expandtab

__END__

