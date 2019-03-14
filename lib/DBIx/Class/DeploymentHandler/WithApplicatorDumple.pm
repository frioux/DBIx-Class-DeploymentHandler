package DBIx::Class::DeploymentHandler::WithApplicatorDumple;

use Moo::Role;
use MooX::Role::Parameterized;
use Module::Runtime 'use_module';
use DBIx::Class::DeploymentHandler::Types -all;

# this is at least a little ghetto and not super well
# thought out.  Take a look at the following at some
# point to clean it all up:
#
# http://search.cpan.org/~jjnapiork/MooseX-Role-BuildInstanceOf-0.06/lib/MooseX/Role/BuildInstanceOf.pm
# http://github.com/rjbs/role-subsystem/blob/master/lib/Role/Subsystem.pm

role {
  my $p = shift;
  my $mop = shift;

  my $class_name = Str->($p->{class_name}) or die;
  my $delegate_name = Str->($p->{delegate_name}) or die;
  my $interface_role = Str->($p->{interface_role}) or die;
  my $attributes_to_assume = (Maybe[ArrayRef[Str]])->($p->{attributes_to_assume}) || [];
  my $attributes_to_copy = (Maybe[ArrayRef[Str]])->($p->{attributes_to_copy}) || [];

  use_module($class_name);

  my $meta = Moo->_constructor_maker_for($class_name);
  my $class_attrs = $meta->all_attribute_specs;

  $mop->has($_ => %{ $class_attrs->{$_} })
    for grep $class_attrs->{$_}, @$attributes_to_copy;

  $mop->has($delegate_name => (
    is         => 'lazy',
    does       => $interface_role,
    handles    => $interface_role,
  ));

  $mop->method('_build_'.$delegate_name => sub {
    my $self = shift;

    $class_name->new({
      map { $_ => $self->$_ }
        @$attributes_to_assume,
        @$attributes_to_copy,
    })
  });
};

1;

# vim: ts=2 sw=2 expandtab

__END__
