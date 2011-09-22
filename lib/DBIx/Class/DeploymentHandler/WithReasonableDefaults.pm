package DBIx::Class::DeploymentHandler::WithReasonableDefaults;
use Moose::Role;

# ABSTRACT: Make default arguments to a few methods sensible

requires qw( prepare_upgrade prepare_downgrade database_version schema_version );

around prepare_upgrade => sub {
  my $orig = shift;
  my $self = shift;
  my $args = shift || {};

  $args->{from_version} ||= $self->database_version;
  $args->{to_version}   ||= $self->schema_version;
  $args->{version_set}  ||= [$args->{from_version}, $args->{to_version}];

  $self->$orig($args);
};


around prepare_downgrade => sub {
  my $orig = shift;
  my $self = shift;

  my $args = shift || {};

  $args->{to_version} ||= $self->database_version;
  $args->{from_version}   ||= $self->schema_version;
  $args->{version_set}  ||= [$args->{from_version}, $args->{to_version}];

  $self->$orig($args);
};

around install_resultsource => sub {
  my $orig = shift;
  my $self = shift;
  my $source = shift;
  my $version = shift || $self->to_version;

  $self->$orig($source, $version);
};

1;

__END__

vim: ts=2 sw=2 expandtab

=head1 CONVENIENCE

The whole point of this role is to set defaults for arguments of various
methods.  It's a little awesome.

=head1 METHODS

=head2 prepare_upgrade

Defaulted args:

  my $from_version = $self->database_version;
  my $to_version   = $self->schema_version;
  my $version_set  = [$from_version, $to_version];

=head2 prepare_downgrade

Defaulted args:

  my $from_version = $self->database_version;
  my $to_version   = $self->schema_version;
  my $version_set  = [$to_version];

=head2 install_resultsource

Defaulted args:

  my $version = $self->to_version;
