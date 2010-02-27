package DBIx::Class::DeploymentHandler::ExplicitVersions;
use Moose;
use Method::Signatures::Simple;
use Carp 'croak';

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
  handles => [qw( ddl_filename schema_version )],
);

has version_rs => (
  isa        => 'DBIx::Class::ResultSet',
  is         => 'ro',
  lazy_build => 1,
  handles    => [qw( is_installed db_version )],
);

method _build_version_rs {
   $self->schema->set_us_up_the_bomb;
   $self->schema->resultset('__VERSION')
}

has to_version => (
  is       => 'ro',
  required => 1,
);

has ordered_versions => (
  is       => 'ro',
  isa      => 'ArrayRef',
  required => 1,
  trigger  => sub {
    my $to_version = $_[0]->to_version;
    my $db_version = $_[0]->db_version;

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
  my $start = $self->version_rs->db_version;
  my $idx = 0;
  for (@{$self->ordered_versions}) {
    return $idx
      if $_ eq $self->db_version;
    $idx++;
  }
  croak 'database version not found in ordered_versions!';
}

method next_version_set {
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
