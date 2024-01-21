#!/usr/bin/perl

use warnings;
use strict;

use VBI::Db;

my $dbh = VBI::Db::get();

# some queries that should run before export to clean up any wonky data

# Strip the childsplay charity "alt" from user title links (otherwise
# I can't reliably do the next search and replace because some values end up
# too wide for the stupid column!
my $q0 = q{
    UPDATE user
       SET usertitle = REPLACE(usertitle, '<a href="http://childsplaycharity.org"><img src="/childsplayico.png" alt="Child\'s Play Charity" style="vertical-align: -25%"></a>', '<a href="https://childsplaycharity.org"><img src="../../smileys/childsplayico.png" style="vertical-align: -25%"></a>')
     WHERE INSTR(usertitle, '<a href="http://childsplaycharity.org"><img src="/childsplayico.png" alt="Child\'s Play Charity" style="vertical-align: -25%"></a>') > 0;
};

$dbh->do($q0) or die $dbh->errstr;

# Actually just copied the images into smileys directory and can just fix the
# paths using SQL
my $q1 = q{
    UPDATE user
       SET usertitle = REPLACE(usertitle, '<img src="/', '<img src="../../smileys/')
     WHERE INSTR(usertitle, '<img src="/') > 0
};

$dbh->do($q1) or die $dbh->errstr;
