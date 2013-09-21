requires 'parent' => 0.225;
requires 'autodie' => 0;
requires 'namespace::autoclean' => 0;
requires 'Log::Contextual' => 0.005005;
requires 'Path::Class' => 0.26;
requires 'DBIx::Class' => 0.08121;
requires 'Moose' => 1.0;
requires 'Moo' => 1.003000;
requires 'MooseX::Role::Parameterized' => 0.18;
requires 'Try::Tiny' => 0;
requires 'SQL::Translator' => 0.11005;
requires 'Carp' => 0;
requires 'Carp::Clan' => 0;
requires 'Context::Preserve' => 0.01;
requires 'Sub::Exporter::Progressive' => 0;
requires 'Text::Brew' => 0.02;

on test => sub {
   requires 'Test::More' => 0.88;
   requires 'Test::Fatal' => 0.006;
   requires 'DBD::SQLite' => 1.35;
   requires 'aliased' => 0;
   requires 'Test::Requires' => 0.06;
   requires 'File::Temp' => 0;
};
