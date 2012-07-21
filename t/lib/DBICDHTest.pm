package DBICDHTest;

use strict;
use warnings;

use File::Path 'remove_tree';
use DBI;

sub dbh {
  DBI->connect('dbi:SQLite::memory:', undef, undef, { RaiseError => 1 })
}

1;
