package DBIx::Class::DeploymentHandler;

# ABSTRACT: Extensible DBIx::Class deployment

use Moose;

extends 'DBIx::Class::DeploymentHandler::Dad';
# a single with would be better, but we can't do that
# see: http://rt.cpan.org/Public/Bug/Display.html?id=46347
with 'DBIx::Class::DeploymentHandler::WithSqltDeployMethod',
     'DBIx::Class::DeploymentHandler::WithMonotonicVersions',
     'DBIx::Class::DeploymentHandler::WithStandardVersionStorage';
with 'DBIx::Class::DeploymentHandler::WithReasonableDefaults';

sub prepare_version_storage_install {
  my $self = shift;

  $self->prepare_resultsource_install(
    $self->version_storage->version_rs->result_source
  );
}

sub install_version_storage {
  my $self = shift;

  $self->install_resultsource(
    $self->version_storage->version_rs->result_source
  );
}

sub prepare_install {
   $_[0]->prepare_deploy;
   $_[0]->prepare_version_storage_install;
}

__PACKAGE__->meta->make_immutable;

1;

#vim: ts=2 sw=2 expandtab

__END__

=head1 SYNOPSIS

 use aliased 'DBIx::Class::DeploymentHandler' => 'DH';
 my $s = My::Schema->connect(...);

 my $dh = DH->new({
   schema => $s,
   databases => 'SQLite',
   sqltargs => { add_drop_table => 0 },
 });

 $dh->prepare_install;

 $dh->install;

or for upgrades:

 use aliased 'DBIx::Class::DeploymentHandler' => 'DH';
 my $s = My::Schema->connect(...);

 my $dh = DH->new({
   schema => $s,
   databases => 'SQLite',
   sqltargs => { add_drop_table => 0 },
 });

 $dh->prepare_upgrade(1, 2);

 $dh->upgrade;

=head1 DESCRIPTION

C<DBIx::Class::DeploymentHandler> is, as it's name suggests, a tool for
deploying and upgrading databases with L<DBIx::Class>.  It is designed to be
much more flexible than L<DBIx::Class::Schema::Versioned>, hence the use of
L<Moose> and lots of roles.

C<DBIx::Class::DeploymentHandler> itself is just a recommended set of roles
that we think will not only work well for everyone, but will also yeild the
best overall mileage.  Each role it uses has it's own nuances and
documentation, so I won't describe all of them here, but here are a few of the
major benefits over how L<DBIx::Class::Schema::Versioned> worked (and
L<DBIx::Class::DeploymentHandler::Deprecated> tries to maintain compatibility
with):

=over

=item *

Downgrades in addition to upgrades.

=item *

Multiple sql files files per upgrade/downgrade/install.

=item *

Perl scripts allowed for upgrade/downgrade/install.

=item *

Just one set of files needed for upgrade, unlike before where one might need
to generate C<factorial(scalar @versions)>, which is just silly.

=item *

And much, much more!

=back

That's really just a taste of some of the differences.  Check out each role for
all the details.

=head1 WHERE IS ALL THE DOC?!

C<DBIx::Class::DeploymentHandler> extends
L<DBIx::Class::DeploymentHandler::Dad>, so that's probably the first place to
look when you are trying to figure out how everything works.

Next would be to look at all the roles that fill in the blanks that
L<DBIx::Class::DeploymentHandler::Dad> expects to be filled.  They would be
L<DBIx::Class::DeploymentHandler::WithSqltDeployMethod>,
L<DBIx::Class::DeploymentHandler::WithMonotonicVersions>,
L<DBIx::Class::DeploymentHandler::WithStandardVersionStorage>, and
L<DBIx::Class::DeploymentHandler::WithReasonableDefaults>.

=method prepare_version_storage_install

 $dh->prepare_version_storage_install

Creates the needed C<.sql> file to install the version storage and not the rest
of the tables

=method prepare_install

 $dh->prepare_install

First prepare all the tables to be installed and the prepare just the version
storage

=method install_version_storage

 $dh->install_version_storage

Install the version storage and not the rest of the tables

=head1 THIS SUCKS

You started your project and weren't using C<DBIx::Class::DeploymentHandler>?
Lucky for you I had you in mind when I wrote this doc.

First off, you'll want to just install the C<version_storage>:

 my $s = My::Schema->connect(...);
 my $dh = DBIx::Class::DeploymentHandler({ schema => $s });

 $dh->prepare_version_storage_install;
 $dh->install_version_storage;

Then set your database version:

 $dh->add_database_version({ version => $s->version });

Now you should be able to use C<DBIx::Class::DeploymentHandler> like normal!

=head1 DONATIONS

If you'd like to thank me for the work I've done on this module, don't give me
a donation. I spend a lot of free time creating free software, but I do it
because I love it.

Instead, consider donating to someone who might actually need it.  Obviously
you should do research when donating to a charity, so don't just take my word
on this.  I like Children's Survival Fund:
L<http://www.childrenssurvivalfund.org>, but there are a host of other
charities that can do much more good than I will with your money.
