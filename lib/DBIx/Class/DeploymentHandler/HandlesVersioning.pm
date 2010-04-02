package DBIx::Class::DeploymentHandler::HandlesVersioning;
use Moose::Role;

# note: the sets returned need to match!
requires 'next_version_set';
requires 'previous_version_set';

1;

__END__

=method next_version_set

 print 'versions to install: ';
 while (my $vs = $dh->next_version_set) {
   print join q(, ), @{$vs}
 }
 print qq(\n);

return an arrayref describing each version that needs to be
installed to upgrade to C<< $dh->to_version >>.

=method previous_version_set

 print 'versions to uninstall: ';
 while (my $vs = $dh->previous_version_set) {
   print join q(, ), @{$vs}
 }
 print qq(\n);

return an arrayref describing each version that needs to be
"installed" to downgrade to C<< $dh->to_version >>.

# normally a VersionHandler will take
# a to_version and yeild an iterator of
# "version sets" or something like that.
#
# A "version set" is basically an arrayref
# of "version numbers" (which we already know
# is vague as is.)  Typically an call to a
# VH w/ a db version of 1 and a "to_version"
# of 5 will iterate over something like this:
# [1, 2]
# [2, 3]
# [3, 4]
# [4, 5]
#
# Of course rob wants to be able to have dep
# management with his versions, so I *think* his
# would work like this:
#
# to_version = 7, db_version = 1
# [1]
# [5]
# [7]
#
# Because 7 depended on 5, 5 was installed first;
# note that this potentially never released module
# doesn't use version pairs, instead it just yeilds
# versions.  Version pairs are too much work for users
# to have to deal with in that sitation.  We may
# actually switch to this for other versioners.
#
# The upshot of all this is that the DeploymentMethod
# needs to be able to take an ArrayRef[VersionNumber],
# instead of just a pair of VersionNumber.
vim: ts=2 sw=2 expandtab
