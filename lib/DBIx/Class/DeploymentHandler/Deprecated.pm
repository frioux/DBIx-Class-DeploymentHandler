package DBIx::Class::DeploymentHandler::Deprecated;

# ABSTRACT: (DEPRECATED) Use this if you are stuck in the past

use Moose;
use Moose::Util 'apply_all_roles';

extends 'DBIx::Class::DeploymentHandler::Dad';
# a single with would be better, but we can't do that
# see: http://rt.cpan.org/Public/Bug/Display.html?id=46347
with 'DBIx::Class::DeploymentHandler::Deprecated::WithDeprecatedSqltDeployMethod',
     'DBIx::Class::DeploymentHandler::Deprecated::WithDeprecatedVersionStorage';
with 'DBIx::Class::DeploymentHandler::WithReasonableDefaults';

sub BUILD {
  my $self = shift;

  if ($self->schema->can('ordered_versions') && $self->schema->ordered_versions) {
    apply_all_roles(
      $self,
      'DBIx::Class::DeploymentHandler::WithExplicitVersions'
    );
  } else {
    apply_all_roles(
      $self,
      'DBIx::Class::DeploymentHandler::WithDatabaseToSchemaVersions'
    );
  }
}

__PACKAGE__->meta->make_immutable;

1;

# vim: ts=2 sw=2 expandtab

__END__

=head1 DEPRECATED

I begrudgingly made this module (and other related modules) to make porting
from L<DBIx::Class::Schema::Versioned> relatively simple.  I will make changes
to ensure that it works with output from L<DBIx::Class::Schema::Versioned> etc,
but I will not add any new features to it.  It already lacks numerous features
that the full version provides in style:

=over

=item *

Downgrades

=item *

Multiple files for migrations

=item *

Perl files in migrations

=item *

Shared Perl/SQL for different databases

=back

And there's probably more.

At version 1.000000 usage of this module will emit a warning.  At version
2.000000 it will be removed entirely.

To migrate to the New Hotness take a look at:
L<DBIx::Class::DeploymentHandler::VersionStorage::Deprecated/THIS SUCKS> and
L<DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::Deprecated/THIS SUCKS>.

=head1 SYNOPSIS

Look at L<DBIx::Class::DeploymentHandler/SYNPOSIS>.  I won't repeat
it here to emphasize, yet again, that this should not be used unless you really
want to live in the past.

=head1 WHERE IS ALL THE DOC?!

C<DBIx::Class::DeploymentHandler::Deprecated> extends
L<DBIx::Class::DeploymentHandler::Dad>, so that's probably the first place to
look when you are trying to figure out how everything works.

Next would be to look at all the roles that fill in the blanks that
L<DBIx::Class::DeploymentHandler::Dad> expects to be filled.  They would be
L<DBIx::Class::DeploymentHandler::Deprecated::WithSqltDeployMethod>,
L<DBIx::Class::DeploymentHandler::Deprecated::WithDeprecatedVersionStorage>, and
L<DBIx::Class::DeploymentHandler::WithReasonableDefaults>.  Also, this class
is special in that it applies either
L<DBIx::Class::DeploymentHandler::WithExplicitVersions> or
L<DBIx::Class::DeploymentHandler::WithDatabaseToSchemaVersions> depending on
your schema.
