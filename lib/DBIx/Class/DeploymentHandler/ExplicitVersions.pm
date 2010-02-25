package DBIx::Class::DeploymentHandler::ExplicitVersions;
use Moose;
use Method::Signatures::Simple;

method ordered_schema_versions { undef }

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
