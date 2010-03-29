package DBICDHTest;

use strict;
use warnings;

use File::Path 'remove_tree';
use Test::More;
use Test::Exception;

sub ready {
   unlink 'db.db' if -e 'db.db';
   if (-d 't/sql') {
     remove_tree('t/sql');
     mkdir 't/sql';
   }
}

1;
