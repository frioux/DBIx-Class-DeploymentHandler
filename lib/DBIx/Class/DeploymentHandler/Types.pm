package DBIx::Class::DeploymentHandler::Types;
use strict;
use warnings;

use Moose::Util::TypeConstraints;
subtype 'DBIx::Class::DeploymentHandler::Databases'
 => as 'ArrayRef[Str]';

coerce 'DBIx::Class::DeploymentHandler::Databases'
 => from 'Str'
 => via { [$_] };
no Moose::Util::TypeConstraints;

1;
