package DBICDHTest;

use strict;
use warnings;

use File::Path 'remove_tree';
use Test::More;

sub ready {
   if (-d 't/sql') {
     remove_tree('t/sql');
     mkdir 't/sql';
   }
}

sub dbh {
  DBI->connect('dbi:SQLite::memory:', undef, undef, { RaiseError => 1 })
}

1;
