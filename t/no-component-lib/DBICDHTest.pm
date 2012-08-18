package DBICDHTest;

use strict;
use warnings;

sub dbh {
  DBI->connect('dbi:SQLite::memory:', undef, undef, { RaiseError => 1 })
}

1;
