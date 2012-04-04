package DBIx::Class::DeploymentHandler::VersionHandler::Monotonic;

use Moo;
use DBIx::Class::DeploymentHandler::Types -all;

# ABSTRACT: Obvious version progressions

use Carp 'croak';

with 'DBIx::Class::DeploymentHandler::HandlesVersioning';

has schema_version => (
  isa      => VersionNonObj,
  coerce   => 1,
  is       => 'ro',
  required => 1,
);

has initial_version => (
  isa      => Int,
  is       => 'ro',
  required => 1,
);

has to_version => (
  isa        => VersionNonObj,
  coerce     => 1,
  is         => 'lazy',
);

sub _build_to_version {
  my $version = $_[0]->schema_version;
  ref($version) ? $version->numify : $version;
}

has _version => (
  is         => 'rw',
  isa        => Int,
  builder    => \&_build__version,
  lazy       => 1,
);

sub _inc_version { $_[0]->_version($_[0]->_version + 1 ) }
sub _dec_version { $_[0]->_version($_[0]->_version - 1 ) }

sub _build__version { $_[0]->initial_version }

# provide backwards compatibility for initial_version/database_version
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $args = $class->$orig(@_);
    $args->{initial_version} = $args->{database_version}
      if exists $args->{database_version} && !exists $args->{initial_version};
    return $args;
};

sub previous_version_set {
  my $self = shift;
  if ($self->to_version > $self->_version) {
    croak "you are trying to downgrade and your current version is less\n".
          "than the version you are trying to downgrade to.  Either upgrade\n".
          "or update your schema"
  } elsif ( $self->to_version == $self->_version) {
    return undef
  } else {
    $self->_dec_version;
    return [$self->_version + 1, $self->_version];
  }
}

sub next_version_set {
  my $self = shift;
  if ($self->to_version < $self->initial_version) {
    croak "you are trying to upgrade and your current version is greater\n".
          "than the version you are trying to upgrade to.  Either downgrade\n".
          "or update your schema"
  } elsif ( $self->to_version == $self->_version) {
    return undef
  } else {
    $self->_inc_version;
    return [$self->_version - 1, $self->_version];
  }
}

__PACKAGE__->meta->make_immutable;

1;

# vim: ts=2 sw=2 expandtab

__END__

=head1 SEE ALSO

This class is an implementation of
L<DBIx::Class::DeploymentHandler::HandlesVersioning>.  Pretty much all the
documentation is there.
