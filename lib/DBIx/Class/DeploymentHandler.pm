package DBIx::Class::DeploymentHandler;

use Moose;

extends 'DBIx::Class::DeploymentHandler::Dad';
# a single with would be better, but we can't do that
# see: http://rt.cpan.org/Public/Bug/Display.html?id=46347
with 'DBIx::Class::DeploymentHandler::WithSqltDeployMethod',
     'DBIx::Class::DeploymentHandler::WithMonotonicVersions',
     'DBIx::Class::DeploymentHandler::WithStandardVersionStorage';
with 'DBIx::Class::DeploymentHandler::WithReasonableDefaults';

sub prepare_version_storage_install {
  my $self = shift;

  $self->prepare_resultsource_install(
    $self->version_storage->version_rs->result_source
  );
}

sub install_version_storage {
  my $self = shift;

  $self->install_resultsource(
    $self->version_storage->version_rs->result_source
  );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
