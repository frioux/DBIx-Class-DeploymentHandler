package DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions;
use Moose;
use Method::Signatures::Simple;
use Carp 'croak';

with 'DBIx::Class::DeploymentHandler::HandlesVersioning';

has schema_version => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

has database_version => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

has to_version => ( # configuration
  is         => 'ro',
  lazy_build => 1, # builder comes from another role...
                   # which is... probably not how we want it
);

sub _build_to_version { $_[0]->schema_version }

has ordered_versions => (
  is       => 'ro',
  isa      => 'ArrayRef',
  required => 1,
  trigger  => sub {
    my $to_version = $_[0]->to_version;
    my $db_version = $_[0]->database_version;

    croak 'to_version not in ordered_versions'
      unless grep { $to_version eq $_ } @{ $_[1] };

    for (@{ $_[1] }) {
      return if $_ eq $db_version;
      croak 'to_version is before database version in ordered_versions'
        if $_ eq $to_version;
    }
  },
);

has _version_idx => (
  is         => 'rw',
  isa        => 'Int',
  lazy_build => 1,
);

method _inc_version_idx { $self->_version_idx($self->_version_idx + 1 ) }

method _build__version_idx {
  my $start = $self->database_version;
  my $idx = 0;
  for (@{$self->ordered_versions}) {
    return $idx
      if $_ eq $self->database_version;
    $idx++;
  }
  croak 'database version not found in ordered_versions!';
}

sub next_version_set { # sub instead of method because of when roles get composed
  my $self = shift;
  return undef
    if $self->ordered_versions->[$self->_version_idx] eq $self->to_version;
  my $next_idx = $self->_inc_version_idx;
  if ( $next_idx <= $#{ $self->ordered_versions }) {
    return [
      $self->ordered_versions->[$next_idx - 1],
      $self->ordered_versions->[$next_idx    ],
    ]
  } else {
    return undef
  }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
