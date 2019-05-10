# This test represents darkpan code that subclasses DH using the recommended
# method. Updates should make sure this doesn't break, since it breaks
# real-world code!

use strict;
use warnings;

use lib 't/lib';
use DBICDHTest;
use DBIx::Class::DeploymentHandler;
{
package DH;

use Moose;

has initial_version => (
  is => 'ro',
  lazy => 1,
  builder => '_build_initial_version',
);
sub _build_initial_version { $_[0]->database_version }

extends 'DBIx::Class::DeploymentHandler::Dad';
# a single with would be better, but we can't do that
# see: http://rt.cpan.org/Public/Bug/Display.html?id=46347
with 'DBIx::Class::DeploymentHandler::WithApplicatorDumple' => {
    interface_role       => 'DBIx::Class::DeploymentHandler::HandlesDeploy',
    class_name           => 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator',
    delegate_name        => 'deploy_method',
    attributes_to_assume => [qw(schema schema_version version_source)],
    attributes_to_copy   => [qw(
      ignore_ddl databases script_directory sql_translator_args force_overwrite
    )],
  },
  'DBIx::Class::DeploymentHandler::WithApplicatorDumple' => {
    interface_role       => 'DBIx::Class::DeploymentHandler::HandlesVersioning',
    class_name           => 'DBIx::Class::DeploymentHandler::VersionHandler::Monotonic',
    delegate_name        => 'version_handler',
    attributes_to_assume => [qw( initial_version schema_version to_version )],
  },
  'DBIx::Class::DeploymentHandler::WithApplicatorDumple' => {
    interface_role       => 'DBIx::Class::DeploymentHandler::HandlesVersionStorage',
    class_name           => 'DBIx::Class::DeploymentHandler::VersionStorage::Standard',
    delegate_name        => 'version_storage',
    attributes_to_assume => ['schema'],
    attributes_to_copy   => [qw(version_source version_class)],
  };
with 'DBIx::Class::DeploymentHandler::WithReasonableDefaults';

sub prepare_version_storage_install {
  my $self = shift;

  $self->prepare_resultsource_install({
    result_source => $self->version_storage->version_rs->result_source
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

# the following is just a hack so that ->version_storage
# won't be lazy
sub BUILD { $_[0]->version_storage }
__PACKAGE__->meta->make_immutable;

}

use Test::More;
use File::Temp 'tempdir';
use Test::Fatal qw(lives_ok dies_ok);

my $dbh = DBICDHTest::dbh();
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = tempdir( CLEANUP => 1 );

VERSION1: {
  use_ok 'DBICVersion_v1';
  my $s = DBICVersion::Schema->connect(@connection);
  $DBICVersion::Schema::VERSION = 1;
  ok($s, 'DBICVersion::Schema 1 instantiates correctly');
  my $handler = DH->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
    sql_translator_args => { add_drop_table => 0 },
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/1 instantiates correctly');

  my $version = $s->schema_version;
  $handler->prepare_install;

  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
    })
  } 'schema not deployed';
  $handler->install;
  dies_ok {
    $handler->install;
  } 'cannot install twice';
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
    })
  } 'schema is deployed';
}

VERSION2: {
  use_ok 'DBICVersion_v2';
  my $s = DBICVersion::Schema->connect(@connection);
  $DBICVersion::Schema::VERSION = 2;
  ok($s, 'DBICVersion::Schema 2 instantiates correctly');
  my $handler = DH->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/2 instantiates correctly');

  my $version = $s->schema_version();
  $handler->prepare_install;
  $handler->prepare_upgrade({ from_version => 1, to_version => $version} );
  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema not deployed';
  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema not uppgrayyed';
  $handler->upgrade;
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema is deployed';
}

VERSION3: {
  use_ok 'DBICVersion_v3';
  my $s = DBICVersion::Schema->connect(@connection);
  $DBICVersion::Schema::VERSION = 3;
  ok($s, 'DBICVersion::Schema 3 instantiates correctly');
  my $handler = DH->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/3 instantiates correctly');

  my $version = $s->schema_version();
  $handler->prepare_install;
  $handler->prepare_upgrade({ from_version => 2, to_version => $version });
  dies_ok {
    $s->resultset('Foo')->create({
        bar => 'frew',
        baz => 'frew',
        biff => 'frew',
      })
  } 'schema not deployed';
  $handler->upgrade;
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
      biff => 'frew',
    })
  } 'schema is deployed';
}

DOWN2: {
  use_ok 'DBICVersion_v4';
  my $s = DBICVersion::Schema->connect(@connection);
  $DBICVersion::Schema::VERSION = 2;
  ok($s, 'DBICVersion::Schema 2 instantiates correctly');
  my $handler = DH->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/2 instantiates correctly');

  my $version = $s->schema_version();
  $handler->prepare_downgrade({ from_version => 3, to_version => $version });
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
      biff => 'frew',
    })
  } 'schema at version 3';
  $handler->downgrade;
  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
      biff => 'frew',
    })
  } 'schema not at version 3';
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema is at version 2';
}

done_testing;
