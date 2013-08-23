package DBIx::Class::DeploymentHandler::Logger;

use warnings;
use strict;

use parent 'Log::Contextual::WarnLogger';

# trace works the way we want it already

# sub is_trace {                  $_[0]->next::method }
sub is_debug { $_[0]->is_trace || $_[0]->next::method }
sub is_info  { $_[0]->is_debug || $_[0]->next::method }

sub is_warn  {
   my $orig = $_[0]->next::method;
   return undef if defined $orig && !$orig;
   return $_[0]->is_info || 1
}

sub is_error {
   my $orig = $_[0]->next::method;
   return undef if defined $orig && !$orig;
   return $_[0]->is_warn || 1
}

sub is_fatal {
   my $orig = $_[0]->next::method;
   return undef if defined $orig && !$orig;
   return $_[0]->is_error || 1
}

sub _log {
  my $self    = shift;
  my $level   = shift;
  my $message = join( "\n", @_ );
  $message .= "\n" unless $message =~ /\n$/;
  warn "[DBICDH] [$level] $message";
}

sub new {
   my ($self, $options, @rest) = @_;

   $options ||= {};
   $options->{env_prefix} ||= 'DBICDH';

   $self->next::method($options, @rest)
}

1;
