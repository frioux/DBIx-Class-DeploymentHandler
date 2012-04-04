package DBIx::Class::DeploymentHandler::WithApplicatorDumple;

use strict;
use warnings;

use Package::Variant
  importing => {
     'Module::Runtime' => ['use_module'],
     'Moo::Role' => ['has'],
  },
  subs => [qw(has use_module)];

sub make_variant {
  my ($class, $target, %args) = @_;

  my $interface_role = $args{interface_role}
    or die 'interface_role is required!';

  my $class_name = $args{class_name}
    or die 'class_name is required!';

  my $delegate_name = $args{delegate_name}
    or die 'delegate_name is required!';

  my $attributes_to_copy = $args{attributes_to_copy} || [];
  my $attributes_to_assume = $args{attributes_to_assume} || [];

  use_module($class_name);

  my $meta = Class::MOP::class_of($class_name);

  has $_->name => %{ $_->clone }
    for grep $_, map $meta->find_attribute_by_name($_), @$attributes_to_copy;

  has $delegate_name => (
    is         => 'ro',
    lazy_build => 1,
    does       => $interface_role,
    handles    => $interface_role,
  );

  install '_build_'.$delegate_name => sub {
    my $self = shift;

    $class_name->new({
      map { $_ => $self->$_ }
        @$attributes_to_assume,
        @$attributes_to_copy,
    })
  };
};

1;

# vim: ts=2 sw=2 expandtab

__END__
