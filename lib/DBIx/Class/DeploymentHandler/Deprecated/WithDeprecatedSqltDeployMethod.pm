package DBIx::Class::DeploymentHandler::Deprecated::WithDeprecatedSqltDeployMethod;
use Moose::Role;

use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::Deprecated;

has deploy_method => (
  does => 'DBIx::Class::DeploymentHandler::HandlesDeploy',
  is  => 'ro',
  lazy_build => 1,
  handles =>  'DBIx::Class::DeploymentHandler::HandlesDeploy',
);

has upgrade_directory => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
  default  => 'sql',
);

has databases => (
  coerce  => 1,
  isa     => 'DBIx::Class::DeploymentHandler::Databases',
  is      => 'ro',
  default => sub { [qw( MySQL SQLite PostgreSQL )] },
);

has sqltargs => (
  isa => 'HashRef',
  is  => 'ro',
  default => sub { {} },
);

sub _build_deploy_method {
  my $self = shift;
  DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::Deprecated->new({
    schema            => $self->schema,
    databases         => $self->databases,
    upgrade_directory => $self->upgrade_directory,
    sqltargs          => $self->sqltargs,
  });
}

1;

# vim: ts=2 sw=2 expandtab

__END__

