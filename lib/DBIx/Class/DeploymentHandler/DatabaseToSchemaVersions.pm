package DBIx::Class::DeploymentHandler::DatabaseToSchemaVersions;
use Moose;
use Method::Signatures::Simple;

with 'DBIx::Class::DeploymentHandler::HandlesVersioning';

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
    if $self->db_version eq $self->to_version;
  return [$self->db_version, $self->to_version];
}


__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
