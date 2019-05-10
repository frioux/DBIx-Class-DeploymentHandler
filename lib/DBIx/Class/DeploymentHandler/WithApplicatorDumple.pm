package DBIx::Class::DeploymentHandler::WithApplicatorDumple;

use MooseX::Role::Parameterized;
use Module::Runtime 'use_module';
use namespace::autoclean;

# this is at least a little ghetto and not super well
# thought out.  Take a look at the following at some
# point to clean it all up:
#
# http://search.cpan.org/~jjnapiork/MooseX-Role-BuildInstanceOf-0.06/lib/MooseX/Role/BuildInstanceOf.pm
# http://github.com/rjbs/role-subsystem/blob/master/lib/Role/Subsystem.pm

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

  use_module($class_name);

  my $meta = Class::MOP::class_of($class_name);

  has $_->name => %{ $_->clone }
    for grep { $_ } map $meta->find_attribute_by_name($_), @{ $p->attributes_to_copy };

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
