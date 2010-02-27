package DBIx::Class::DeploymentHandler::WithSqltDeployMethod;
use Moose::Role;

use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator;

has deploy_method => (
  does => 'DBIx::Class::DeploymentHandler::HandlesDeploy',
  is  => 'ro',
  lazy_build => 1,
  handles =>  'DBIx::Class::DeploymentHandler::HandlesDeploy',
);

sub _build_deploy_method {
  my $self = shift;
  my $args = {
    schema            => $self->schema,
    databases         => $self->databases,
    upgrade_directory => $self->upgrade_directory,
    sqltargs          => $self->sqltargs,
    do_backup         => $self->do_backup,
  };
  $args->{backup_directory} = $self->backup_directory
    if $self->has_backup_directory;
  DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator->new($args);
}

1;

__END__

vim: ts=2 sw=2 expandtab
