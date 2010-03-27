package DBIx::Class::DeploymentHandler::HandlesDeploy;
use Moose::Role;

requires 'prepare_install';
requires 'prepare_upgrade';
requires 'prepare_downgrade';
requires 'upgrade_single_step';
requires 'downgrade_single_step';
requires 'deploy';

1;

__END__

vim: ts=2 sw=2 expandtab
