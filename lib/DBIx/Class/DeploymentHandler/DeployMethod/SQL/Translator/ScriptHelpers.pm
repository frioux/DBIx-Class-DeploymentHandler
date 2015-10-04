package DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::ScriptHelpers;

# ABSTRACT: CodeRef Transforms for common use-cases in DBICDH Migrations

use strict;
use warnings;

use Sub::Exporter::Progressive -setup => {
  exports => [qw(dbh schema_from_schema_loader)],
};

use List::Util 'first';
use Text::Brew 'distance';
use Try::Tiny;
use DBIx::Class::DeploymentHandler::LogImporter qw(:dlog);

sub dbh {
   my ($code) = @_;
   sub {
      my ($schema, $versions) = @_;
      $schema->storage->dbh_do(sub {
         $code->($_[1], $versions)
      })
   }
}

sub _rearrange_connect_info {
   my ($storage) = @_;

   my $nci = $storage->_normalize_connect_info($storage->connect_info);

   return {
      dbh_maker => sub { $storage->dbh },
      map %{$nci->{$_}}, grep { $_ ne 'arguments' } keys %$nci,
   };
}

my $count = 0;
sub schema_from_schema_loader {
   my ($opts, $code) = @_;

   die 'schema_from_schema_loader requires options!'
      unless $opts && ref $opts && ref $opts eq 'HASH';

   die 'schema_from_schema_loader requires naming settings to be set!'
      unless $opts->{naming};

   warn 'using "current" naming in a deployment script is begging for problems.  Just Say No.'
      if $opts->{naming} eq 'current' ||
        (ref $opts->{naming} eq 'HASH' && first { $_ eq 'current' } values %{$opts->{naming}});

   $opts->{debug} = 1
      if !exists $opts->{debug} && $ENV{DBICDH_TRACE};

   sub {
      my ($schema, $versions) = @_;

      require DBIx::Class::Schema::Loader;

      $schema->storage->ensure_connected;
      my @ci = _rearrange_connect_info($schema->storage);

      my $new_schema = DBIx::Class::Schema::Loader::make_schema_at(
        'SHSchema::' . $count++, $opts, \@ci
      );

      Dlog_debug {
         "schema_from_schema_loader generated the following sources: $_"
      } [ $new_schema->sources ];
      my $sl_schema = $new_schema->connect(@ci);
      try {
         $code->($sl_schema, $versions)
      } catch {
         if (m/Can't find source for (.+?) at/) {
            my @presentsources = map {
              (distance($_, $1))[0] < 3 ? "$_ <== Possible Match\n" : "$_\n";
            } $sl_schema->sources;

            die <<"ERR";
$_
You are seeing this error because the DBIx::Class::ResultSource in your
migration script called "$1" is not part of the schema that ::Schema::Loader
has inferred from your existing database.

To help you debug this issue, here's a list of the actual sources that the
schema available to your migration knows about:

 @presentsources
ERR
         }
         die $_;
      }
   }
}

1;

__END__

=head1 SYNOPSIS

 use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::ScriptHelpers
   'schema_from_schema_loader';

   schema_from_schema_loader({ naming => 'v4' }, sub {
      my ($schema, $version_set) = @_;

      ...
   });

=head1 DESCRIPTION

This package is a set of coderef transforms for common use-cases in migrations.
The subroutines are simply helpers for creating coderefs that will work for
L<DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator/PERL SCRIPTS>,
yet have some argument other than the current schema that you as a user might
prefer.

=head1 EXPORTED SUBROUTINES

=head2 dbh($coderef)

 dbh(sub {
   my ($dbh, $version_set) = @_;

   ...
 });

For those times when you almost exclusively need access to "the bare metal".
Simply gives you the correct database handle and the expected version set.

=head2 schema_from_schema_loader($sl_opts, $coderef)

 schema_from_schema_loader({ naming => 'v4' }, sub {
   my ($schema, $version_set) = @_;

   ...
 });

Any time you write a perl migration script that uses a L<DBIx::Class::Schema>
you should probably use this.  Otherwise you'll run into problems if you remove
a column from your schema yet still populate to it in an older population
script.

Note that C<$sl_opts> requires that you specify something for the C<naming>
option.

=head1 CUSTOM SCRIPT HELPERS

If you find that in your scripts you need to always pass the same arguments to
your script helpers, you may want to define a custom set of script helpers.  I
am not sure that there is a better way than just using Perl and other modules
that are already installed when you install L<DBIx::Class::DeploymentHandler>.

The following is a pattern that will get you started; if anyone has ideas on
how to make this even easier let me know.

 package MyApp::DBICDH::ScriptHelpers;

 use strict;
 use warnings;

 use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::ScriptHelpers
    dbh => { -as => '_old_dbh' },
    schema_from_schema_loader => { -as => '_old_sfsl' };

 use Sub::Exporter::Progressive -setup => {
    exports => [qw(dbh schema_from_schema_loader)],
 };

 sub dbh {
    my $coderef = shift;

    _old_dbh(sub {
       my ($dbh) = @_;
       $dbh->do(q(SET search_path TO 'myapp_db'));

       $coderef->(@_);
    });
 }

 sub schema_from_schema_loader {
    my ($config, $coderef) = @_;

    $config->{naming} ||= 'v7';

    _old_sfsl(sub {
       my ($schema) = @_;
       $schema->storage->dbh->do(q(SET search_path TO 'myapp_db'));

       $coderef->(@_);
    });

 }

The above will default the naming to C<v7> when using
C<schema_from_schema_loader>.  And in both cases it will set the schema for
PostgreSQL. Of course if you do that you will not be able to switch to MySQL or
something else, so I recommended looking into my L<DBIx::Introspector> to only
do that for the database in question.
