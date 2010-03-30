package DBIx::Class::DeploymentHandler::HandlesDeploy;
use Moose::Role;

requires 'prepare_install';
requires 'prepare_resultsource_install';
requires 'install_resultsource';
requires 'prepare_upgrade';
requires 'prepare_downgrade';
requires 'upgrade_single_step';
requires 'downgrade_single_step';
requires 'deploy';

1;

__END__

# should this be renamed prepare_deploy?

=method prepare_install

 $deploy_method->prepare_install;

=method deploy

 $deploy_method->deploy;

=method prepare_resultsource_install

 $deploy_method->prepare_resultsource_install($resultset->result_source);

=method install_resultsource

 $deploy_method->prepare_resultsource_install($resultset->result_source);

# for updates prepared automatically (rob's stuff)
# one would want to explicitly set $version_set to
# [$to_version]

=method prepare_upgrade

 $deploy_method->prepare_upgrade(1, 2, [1, 2]);

# for updates prepared automatically (rob's stuff)
# one would want to explicitly set $version_set to
# [$to_version]

=method prepare_downgrade

 $deploy_method->prepare_downgrade(2, 1, [1, 2]);

=method upgrade_single_step

 $deploy_method->upgrade_single_step([1, 2]);

=method downgrade_single_step

 $deploy_method->upgrade_single_step([1, 2]);

vim: ts=2 sw=2 expandtab
