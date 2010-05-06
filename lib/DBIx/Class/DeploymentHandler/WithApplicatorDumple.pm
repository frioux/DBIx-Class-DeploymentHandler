package DBIx::Class::DeploymentHandler::WithApplicatorDumple;
use MooseX::Role::Parameterized;
use Class::MOP;
use namespace::autoclean;

parameter interface_role => (
  isa      => 'Str',
  required => 1,
);

parameter class_name => (
  isa      => 'Str',
  required => 1,
);

parameter delegate_name => (
  isa      => 'Str',
  required => 1,
);

parameter attributes_to_copy => (
  isa => 'ArrayRef[Str]',
  default => sub {[]},
);

parameter attributes_to_assume => (
  isa => 'ArrayRef[Str]',
  default => sub {[]},
);

role {
  my $p = shift;

  my $class_name = $p->class_name;

  Class::MOP::load_class($class_name);

  my $meta = Class::MOP::class_of($class_name);

  has $_->name => %{ $_->clone }
    for grep { $_ } map $meta->get_attribute($_), @{ $p->attributes_to_copy };

  has $p->delegate_name => (
    is         => 'ro',
    lazy_build => 1,
    does       => $p->interface_role,
    handles    => $p->interface_role,
  );

  method '_build_'.$p->delegate_name => sub {
    my $self = shift;

    $class_name->new({
      map { $_ => $self->$_ }
        @{ $p->attributes_to_assume },
        @{ $p->attributes_to_copy   },
    })
  };
};

1;

# vim: ts=2 sw=2 expandtab

__END__
