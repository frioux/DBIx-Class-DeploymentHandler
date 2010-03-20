package DBIx::Class::DeploymentHandler::HandlesDeploy;
use Moose::Role;

requires 'prepare_install';
requires 'prepare_upgrade';
requires 'prepare_downgrade';
requires '_upgrade_single_step';
requires '_downgrade_single_step';
requires '_deploy';

1;

__END__

vim: ts=2 sw=2 expandtab
