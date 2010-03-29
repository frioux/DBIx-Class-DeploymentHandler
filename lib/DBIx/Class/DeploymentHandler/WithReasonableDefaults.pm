package DBIx::Class::DeploymentHandler::WithReasonableDefaults;
use Moose::Role;

requires qw( prepare_upgrade prepare_downgrade database_version schema_version );

around prepare_upgrade => sub {
  my $orig = shift;
  my $self = shift;

  my $from_version = shift || $self->database_version;
  my $to_version   = shift || $self->schema_version;
  my $version_set  = shift || [$from_version, $to_version];

  $self->$orig($from_version, $to_version, $version_set);
};


around prepare_downgrade => sub {
  my $orig = shift;
  my $self = shift;

  my $from_version = shift || $self->database_version;
  my $to_version   = shift || $self->schema_version;
  my $version_set  = shift || [$to_version, $from_version];

  $self->$orig($from_version, $to_version, $version_set);
};


1;

__END__

vim: ts=2 sw=2 expandtab
