package DBIx::Class::DeploymentHandler;

# ABSTRACT: Extensible DBIx::Class deployment

use Moose;

use Moose::Util qw/ with_traits /;

use DBIx::Class::DeploymentHandler::Types;
require DBIx::Class::Schema;    # loaded for type constraint

use Carp::Clan '^DBIx::Class::DeploymentHandler';
use DBIx::Class::DeploymentHandler::LogImporter ':log';
use DBIx::Class::DeploymentHandler::Types;

has script_directory => (
  isa      => 'Str',
  is       => 'ro',
  default  => 'sql',
);

has ignore_ddl => (
  isa      => 'Bool',
  is       => 'ro',
  default  => undef,
);

has databases => (
  coerce  => 1,
  isa     => 'DBIx::Class::DeploymentHandler::Databases',
  is      => 'ro',
  default => sub { [qw( MySQL SQLite PostgreSQL )] },
);

has deploy_handler_class => (
    is => 'ro',
    isa => 'Str',
    default => 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator'
);

has version_handler_class => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has storage_handler_class => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has additional_roles => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1,
);


has schema => (
  is       => 'ro',
  required => 1,
);

has schema_version => (
    is => 'ro',
    lazy => 1,
    default => sub { $_[0]->schema->schema_version },
);


has backup_directory => (
  isa => 'Str',
  is  => 'ro',
  predicate  => 'has_backup_directory',
);

has to_version => (
  is         => 'ro',
  isa        => 'Str',
  lazy_build => 1,
);

sub _build_to_version { $_[0]->schema_version }

has schema_version => (
  is         => 'ro',
  isa        => 'StrSchemaVersion',
  lazy_build => 1,
);

sub _build_schema_version { $_[0]->schema->schema_version }

sub new {
    my( $class, @args ) = @_;

    my %args = @args == 1 ? %{$args[0]} : @args;

    my $new_class = $class;

    my @handlers = (
      # [ role,             arg,        default ]
        [ 'Deploy',         'deploy',  'DeployMethod::SQL::Translator' ],
        [ 'Versioning',     'version', 'VersionHandler::Monotonic' ],
        [ 'VersionStorage', 'storage', 'VersionStorage::Standard' ],
    );

    for my $handler ( @handlers ) {
        my( $role, $arg, $default ) = @$handler;

        next if $new_class->does('DBIx::Class::DeploymentHandler::Handles'.$role);

        my $handler = $args{$arg."_handler_class"} ||= 'DBIx::Class::DeploymentHandler::'.$default;
        $new_class = $new_class->with_traits( $handler );
    }

    my $additional = $args{additional_roles} ||= [ 'DBIx::Class::DeploymentHandler::WithReasonableDefaults' ];
    $new_class = $new_class->with_traits( @$additional ) if @$additional;

    $new_class->SUPER::new(%args);
}

sub install {
  my $self = shift;

  my $version = (shift @_ || {})->{version} || $self->to_version;
  log_info { "installing version $version" };
  croak 'Install not possible as versions table already exists in database'
    if $self->version_storage_is_installed;

  $self->txn_do(sub {
     my $ddl = $self->deploy({ version=> $version });

     $self->add_database_version({
       version     => $version,
       ddl         => $ddl,
     });
  });
}

sub upgrade {
  log_info { 'upgrading' };
  my $self = shift;
  my $ran_once = 0;
  $self->txn_do(sub {
     while ( my $version_list = $self->next_version_set ) {
       $ran_once = 1;
       my ($ddl, $upgrade_sql) = @{
         $self->upgrade_single_step({ version_set => $version_list })
       ||[]};

       $self->add_database_version({
         version     => $version_list->[-1],
         ddl         => $ddl,
         upgrade_sql => $upgrade_sql,
       });
     }
  });

  log_warn { 'no need to run upgrade' } unless $ran_once;
}

sub downgrade {
  log_info { 'downgrading' };
  my $self = shift;
  my $ran_once = 0;
  $self->txn_do(sub {
     while ( my $version_list = $self->previous_version_set ) {
       $ran_once = 1;
       $self->downgrade_single_step({ version_set => $version_list });

       # do we just delete a row here?  I think so but not sure
       $self->delete_database_version({ version => $version_list->[0] });
     }
  });
  log_warn { 'no version to run downgrade' } unless $ran_once;
}

sub backup {
  my $self = shift;
  log_info { 'backing up' };
  $self->schema->storage->backup($self->backup_directory)
}


sub prepare_version_storage_install {
  my $self = shift;

  $self->prepare_resultsource_install({
    result_source => $self->version_rs->result_source
  });
}

sub install_version_storage {
  my $self = shift;

  my $version = (shift||{})->{version} || $self->schema_version;

  $self->install_resultsource({
    result_source => $self->version_storage->version_rs->result_source,
    version       => $version,
  });
}

sub prepare_install {
  $_[0]->prepare_deploy;
  $_[0]->prepare_version_storage_install;
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;

#vim: ts=2 sw=2 expandtab

__END__

=head1 SYNOPSIS

 use aliased 'DBIx::Class::DeploymentHandler' => 'DH';
 my $s = My::Schema->connect(...);

 my $dh = DH->new({
   schema              => $s,
   databases           => 'SQLite',
   sql_translator_args => { add_drop_table => 0 },
 });

 $dh->prepare_install;

 $dh->install;

or for upgrades:

 use aliased 'DBIx::Class::DeploymentHandler' => 'DH';
 my $s = My::Schema->connect(...);

 my $dh = DH->new({
   schema              => $s,
   databases           => 'SQLite',
   sql_translator_args => { add_drop_table => 0 },
 });

 $dh->prepare_deploy;
 $dh->prepare_upgrade({
   from_version => 1,
   to_version   => 2,
 });

 $dh->upgrade;

=head1 DESCRIPTION

C<DBIx::Class::DeploymentHandler> is, as its name suggests, a tool for
deploying and upgrading databases with L<DBIx::Class>.  It is designed to be
much more flexible than L<DBIx::Class::Schema::Versioned>, hence the use of
L<Moose> and lots of roles.

C<DBIx::Class::DeploymentHandler> itself is just a recommended set of roles
that we think will not only work well for everyone, but will also yield the
best overall mileage.  Each role it uses has its own nuances and
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

Next would be to look at all the pieces that fill in the blanks that
L<DBIx::Class::DeploymentHandler::Dad> expects to be filled.  They would be
L<DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator>,
L<DBIx::Class::DeploymentHandler::VersionHandler::Monotonic>,
L<DBIx::Class::DeploymentHandler::VersionStorage::Standard>, and
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

=head1 WHY IS THIS SO WEIRD

C<DBIx::Class::DeploymentHandler> has a strange structure.  The gist is that it
delegates to three small objects that are proxied to via interface roles that
then create the illusion of one large, monolithic object.  Here is a diagram
that might help:

=begin ditaa

                    +------------+
                    |            |
       +------------+ Deployment +-----------+
       |            |  Handler   |           |
       |            |            |           |
       |            +-----+------+           |
       |                  |                  |
       |                  |                  |
       :                  :                  :
       v                  v                  v
  /-=-------\        /-=-------\       /-=----------\
  |         |        |         |       |            |  (interface roles)
  | Handles |        | Handles |       |  Handles   |
  | Version |        | Deploy  |       | Versioning |
  | Storage |        |         |       |            |
  |         |        \-+--+--+-/       \-+---+---+--/
  \-+--+--+-/          |  |  |           |   |   |
    |  |  |            |  |  |           |   |   |
    |  |  |            |  |  |           |   |   |
    v  v  v            v  v  v           v   v   v
 +----------+        +--------+        +-----------+
 |          |        |        |        |           |  (implementations)
 | Version  |        | Deploy |        |  Version  |
 | Storage  |        | Method |        |  Handler  |
 | Standard |        | SQLT   |        | Monotonic |
 |          |        |        |        |           |
 +----------+        +--------+        +-----------+

=end ditaa

The nice thing about this is that we have well defined interfaces for the
objects that comprise the C<DeploymentHandler>, the smaller objects can be
tested in isolation, and the smaller objects can even be swapped in easily.  But
the real win is that you can subclass the C<DeploymentHandler> without knowing
about the underlying delegation; you just treat it like normal Perl and write
methods that do what you want.

=head1 THIS SUCKS

You started your project and weren't using C<DBIx::Class::DeploymentHandler>?
Lucky for you I had you in mind when I wrote this doc.

First,
L<define the version|DBIx::Class::DeploymentHandler::Manual::Intro/Sample_database>
in your main schema file (maybe using C<$VERSION>).

Then you'll want to just install the version_storage:

 my $s = My::Schema->connect(...);
 my $dh = DBIx::Class::DeploymentHandler->new({ schema => $s });

 $dh->prepare_version_storage_install;
 $dh->install_version_storage;

Then set your database version:

 $dh->add_database_version({ version => $s->schema_version });

Now you should be able to use C<DBIx::Class::DeploymentHandler> like normal!

=head1 LOGGING

This is a complex tool, and because of that sometimes you'll want to see
what exactly is happening.  The best way to do that is to use the built in
logging functionality.  It the standard six log levels; C<fatal>, C<error>,
C<warn>, C<info>, C<debug>, and C<trace>.  Most of those are pretty self
explanatory.  Generally a safe level to see what all is going on is debug,
which will give you everything except for the exact SQL being run.

To enable the various logging levels all you need to do is set an environment
variables: C<DBICDH_FATAL>, C<DBICDH_ERROR>, C<DBICDH_WARN>, C<DBICDH_INFO>,
C<DBICDH_DEBUG>, and C<DBICDH_TRACE>.  Each level can be set on its own,
but the default is the first three on and the last three off, and the levels
cascade, so if you turn on trace the rest will turn on automatically.

=head1 DONATIONS

If you'd like to thank me for the work I've done on this module, don't give me
a donation. I spend a lot of free time creating free software, but I do it
because I love it.

Instead, consider donating to someone who might actually need it.  Obviously
you should do research when donating to a charity, so don't just take my word
on this.  I like Matthew 25: Ministries:
L<http://www.m25m.org/>, but there are a host of other
charities that can do much more good than I will with your money.
(Third party charity info here:
L<http://www.charitynavigator.org/index.cfm?bay=search.summary&orgid=6901>
