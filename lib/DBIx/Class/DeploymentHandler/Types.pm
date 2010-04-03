package DBIx::Class::DeploymentHandler::Types;
use strict;
use warnings;

# ABSTRACT: Types internal to DBIx::Class::DeploymentHandler

use Moose::Util::TypeConstraints;
subtype 'DBIx::Class::DeploymentHandler::Databases'
 => as 'ArrayRef[Str]';

coerce 'DBIx::Class::DeploymentHandler::Databases'
 => from 'Str'
 => via { [$_] };
no Moose::Util::TypeConstraints;

1;

# vim: ts=2 sw=2 expandtab

__END__

