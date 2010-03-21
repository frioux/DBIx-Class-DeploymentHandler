package DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::Deprecated;
use Moose;
use Method::Signatures::Simple;

use File::Spec::Functions;

extends 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator',

method _ddl_schema_consume_filenames($type, $version) {
	return [$self->_ddl_schema_produce_filename($type, $version)]
}

method _ddl_schema_produce_filename($type, $version) {
  my $filename = ref $self->schema;
  $filename =~ s/::/-/g;

  $filename = catfile(
    $self->upgrade_directory, "$filename-$version-$type.sql"
  );

  return $filename;
}

method _ddl_schema_up_produce_filename($type, $versions, $dir) {
  my $filename = ref $self->schema;
  $filename =~ s/::/-/g;

  $filename = catfile(
    $self->upgrade_directory, "$filename-" . join( q(-), @{$versions} ) . "-$type.sql"
  );

  return $filename;
}

method _ddl_schema_up_consume_filenames($type, $versions) {
	return [$self->_ddl_schema_up_produce_filename($type, $versions)]
}

__PACKAGE__->meta->make_immutable;

1;
