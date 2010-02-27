package DBIx::Class::DeploymentHandler::HandlesVersioning;
use Moose::Role;

requires 'next_version_set';

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
  handles => [qw( schema_version )],
);

has version_rs => (
  isa        => 'DBIx::Class::ResultSet',
  is         => 'ro',
  lazy_build => 1,
  handles    => [qw( is_installed db_version )],
);

sub _build_version_rs {
   $_[0]->schema->set_us_up_the_bomb;
   $_[0]->schema->resultset('__VERSION')
}

has to_version => (
  is         => 'ro',
  lazy_build => 1,
);

sub _build_to_version { $_[0]->schema->schema_version }

1;

__END__

# normally a VersionHandler will take
# a to_version and yeild an iterator of
# "version sets" or something like that.
#
# A "version set" is basically an arrayref
# of "version numbers" (which we already know
# is vague as is.)  Typically an call to a
# VH w/ a db version of 1 and a "to_version"
# of 5 will iterate over something like this:
# [1, 2]
# [2, 3]
# [3, 4]
# [4, 5]
#
# Of course rob wants to be able to have dep
# management with his versions, so I *think* his
# would work like this:
#
# to_version = 7, db_version = 1
# [1]
# [5]
# [7]
#
# Because 7 depended on 5, 5 was installed first;
# note that this potentially never released module
# doesn't use version pairs, instead it just yeilds
# versions.  Version pairs are too much work for users
# to have to deal with in that sitation.  We may
# actually switch to this for other versioners.
#
# The upshot of all this is that the DeploymentMethod
# needs to be able to take an ArrayRef[VersionNumber],
# instead of just a pair of VersionNumber.
vim: ts=2 sw=2 expandtab
