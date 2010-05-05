package DBIx::Class::DeploymentHandler::WithExplicitVersions;
use Moose::Role;

# ABSTRACT: Delegate/Role for DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions

use DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions;

use Carp 'carp';

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
  DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions->new($args);
}

1;

# vim: ts=2 sw=2 expandtab

__END__

=head1 DELEGATION ROLE

This role is entirely for making delegation look like a role.  The actual
docs for the methods and attributes are at
L<DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions>
