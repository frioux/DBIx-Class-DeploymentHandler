package DBIx::Class::DeploymentHandler::HandlesVersioning;

use Moose::Role;

# ABSTRACT: Interface for version methods

requires 'next_version_set';
requires 'previous_version_set';

1;

# vim: ts=2 sw=2 expandtab

__END__

=head1 DESCRIPTION

Typically a VersionHandler will take a C<to_version> and yeild an iterator of
L<version sets|/VERSION SET>.

Typically a call to a VersionHandler's L</next_version_set> with a C<db_version>
of 1 and a C<to_version> of 5 will iterate over something like the following:

 [1, 2]
 [2, 3]
 [3, 4]
 [4, 5]
 undef

or maybe just

 [1, 5]
 undef

Really how the L<version sets|/VERSION SET> are arranged is up to the
VersionHandler being used.

In some cases users will not want versions to have inherent "previous
versions," which is why the version set is an C<ArrayRef>.  In those cases the
user should opt to returning merely the version that the database is being
upgraded to in each step.

One idea that has been suggested to me has been to have a form of dependency
management of the database "versions."  In this case the versions are actually
more like features that may or may not be applied.  For example, one might
start with version 1 and have a feature (version) C<users>.

Each feature might require that the database be upgraded to another version
first.  If one were to implement a system like this, here is how the
VersionHandler's L</next_version_set> might look.

 to_version = "users", db_version = 1
 [3]
 [5]
 ["users"]
 undef

So what just happened there is that C<users> depends on version 5, which depends
on version 3, which depends on version 1, which is already installed.  To be
clear, the reason we use single versions instead of version pairs is because
there is no inherent order for this type of database upgraded.

=head2 Downgrades

For the typical case downgrades should be easy for users to perform and
understand.  That means that with the first two examples given above we can use
the L</previous_version_set> iterator to yeild the following:


 db_version = 5, to_version=1
 [5, 4]
 [4, 3]
 [3, 2]
 [2, 1]
 undef

or maybe just

 [5, 1]
 undef

Note that we do not swap the version number order.  This allows us to remain
consistent in our version set abstraction, since a version set really just
describes a version change, and not necessarily a defined progression.

=method next_version_set

 print 'versions to install: ';
 while (my $vs = $dh->next_version_set) {
   print join q(, ), @{$vs}
 }
 print qq(\n);

Return a L<version set|/VERSION SET> describing each version that needs to be
installed to upgrade to C<< $dh->to_version >>.

=method previous_version_set

 print 'versions to uninstall: ';
 while (my $vs = $dh->previous_version_set) {
   print join q(, ), @{$vs}
 }
 print qq(\n);

Return a L<version set|/VERSION SET> describing each version that needs to be
"installed" to downgrade to C<< $dh->to_version >>.

=head1 VERSION SET

A version set could be defined as:

 subtype 'Version', as 'Str';
 subtype 'VersionSet', as 'ArrayRef[Str]';

A version set should uniquely identify a migration.

=head1 KNOWN IMPLEMENTATIONS

=over

=item *

L<DBIx::Class::DeploymentHandler::VersionHandler::Monotonic>

=item *

L<DBIx::Class::DeploymentHandler::VersionHandler::DatabaseToSchemaVersions>

=item *

L<DBIx::Class::DeploymentHandler::VersionHandler::ExplicitVersions>

=back

