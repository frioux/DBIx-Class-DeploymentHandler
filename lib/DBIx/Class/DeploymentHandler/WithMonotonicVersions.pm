package DBIx::Class::DeploymentHandler::WithMonotonicVersions;
use Moose::Role;

use DBIx::Class::DeploymentHandler::VersionHandler::Monotonic;

has version_handler => (
  is         => 'ro',
  lazy_build => 1,
  does       => 'DBIx::Class::DeploymentHandler::HandlesVersioning',
  handles    => 'DBIx::Class::DeploymentHandler::HandlesVersioning',
);

sub _build_version_handler {
  my $self = shift;

  my $args = {
    database_version => $self->database_version,
    schema_version   => $self->schema_version,
  };

  $args->{to_version} = $self->to_version if $self->has_to_version;
  DBIx::Class::DeploymentHandler::VersionHandler::Monotonic->new($args);
}

1;

__END__

vim: ts=2 sw=2 expandtab
