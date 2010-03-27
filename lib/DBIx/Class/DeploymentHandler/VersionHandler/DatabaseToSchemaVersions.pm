package DBIx::Class::DeploymentHandler::VersionHandler::DatabaseToSchemaVersions;
use Moose;
use Method::Signatures::Simple;

with 'DBIx::Class::DeploymentHandler::HandlesVersioning';

has schema_version => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

has database_version => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

has to_version => ( # configuration
  is         => 'ro',
  lazy_build => 1, # builder comes from another role...
                   # which is... probably not how we want it
);

sub _build_to_version { $_[0]->schema_version }

has once => (
  is      => 'rw',
  isa     => 'Bool',
  default => undef,
);

sub next_version_set {
  my $self = shift;
  return undef
    if $self->once;

  $self->once(!$self->once);
  return undef
    if $self->database_version eq $self->to_version;
  return [$self->database_version, $self->to_version];
}

sub previous_version_set {
  my $self = shift;
  return undef
    if $self->once;

  $self->once(!$self->once);
  return undef
    if $self->database_version eq $self->to_version;
  return [$self->database_version, $self->to_version];
}


__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
