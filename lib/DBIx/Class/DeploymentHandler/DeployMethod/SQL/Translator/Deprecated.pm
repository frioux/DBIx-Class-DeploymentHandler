package DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::Deprecated;
use Moose;
use Method::Signatures::Simple;

extends 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator',

method _ddl_schema_filename($type, $version, $dir) {
  my $filename = ref $self->schema;
  $filename =~ s/::/-/g;

  $filename = File::Spec->catfile(
    $dir, "$filename-schema-$version-$type.sql"
  );

  return [$filename];
}

method _ddl_schema_diff_filename($type, $versions, $dir) {
  my $filename = ref $self->schema;
  $filename =~ s/::/-/g;

  $filename = File::Spec->catfile(
    $dir, "$filename-diff-" . join( q(-), @{$versions} ) . "-$type.sql"
  );

  return [$filename];
}

1;
