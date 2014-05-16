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
