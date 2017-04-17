package DBIx::Class::Role::DHObject;

use strict;
use warnings;

use Moose::Role;

has dh => (
    is => 'ro',
    required => 1,
    handles => [ qw/ schema_version schema ignore_ddl databases script_directory force_overwrite / ],
);

1;

