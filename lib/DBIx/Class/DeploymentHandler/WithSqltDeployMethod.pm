package DBIx::Class::DeploymentHandler::WithSqltDeployMethod;
use Moose::Role;

use DBIx::Class::DeploymentHandler::SqltDeployMethod;

use Carp 'carp';

has deploy_method => (

# < mst> isa => 'DBIx::Class::DeploymentHandler::SqltDeployMethod',
# < mst> should be
# < mst> does => <some role>
# < mst> and that role should supply those methods
# < mst> then you can pass handles => <some role> as well

  isa => 'DBIx::Class::DeploymentHandler::SqltDeployMethod',
  is  => 'ro',
  lazy_build => 1,
  handles => [qw{
    deployment_statements
    deploy
	 create_install_ddl
	 create_update_ddl
	 create_ddl_dir
	 upgrade_single_step
  }],
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
	DBIx::Class::DeploymentHandler::SqltDeployMethod->new($args);
}

1;

__END__

vim: ts=2,sw=2,expandtab
