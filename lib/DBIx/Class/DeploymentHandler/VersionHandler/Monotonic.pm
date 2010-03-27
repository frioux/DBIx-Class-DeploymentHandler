package DBIx::Class::DeploymentHandler::VersionHandler::Monotonic;
use Moose;
use Carp 'croak';

with 'DBIx::Class::DeploymentHandler::HandlesVersioning';

has schema_version => (
  isa      => 'Int',
  is       => 'ro',
  required => 1,
);

has database_version => (
  isa      => 'Int',
  is       => 'ro',
  required => 1,
);

has to_version => (
  isa        => 'Int',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_to_version { $_[0]->schema_version }

has _version => (
  is         => 'rw',
  isa        => 'Int',
  lazy_build => 1,
);

sub BUILD {
  croak "you are trying to upgrade and your current version is greater\n".
        "than the version you are trying to upgrade to.  Either downgrade\n".
        "or update your schema" if $_[0]->to_version < $_[0]->_version;
}

sub _inc_version { $_[0]->_version($_[0]->_version + 1 ) }
sub _dec_version { $_[0]->_version($_[0]->_version - 1 ) }

sub _build__version { $_[0]->database_version }

sub previous_version_set {
  my $self = shift;
  return undef
    if $self->to_version == $self->_version;

  $self->_dec_version;
  return [$self->_version, $self->_version + 1];
}

sub next_version_set {
  my $self = shift;
  return undef
    if $self->to_version == $self->_version;

  $self->_inc_version;
  return [$self->_version - 1, $self->_version];
}

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
