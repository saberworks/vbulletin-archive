package VBI::Db;

use warnings;
use strict;

use local::lib;

use DBI;

use VBI::Conf;

my $conf = VBI::Conf::get();

sub get {
    my $dsn_fmt = "DBI:mysql:host=%s;database=%s";
    my $dsn = sprintf($dsn_fmt, $conf->{'db_host'}, $conf->{'db_name'});

    my %attr = (
        PrintError => 0,
        RaiseError => 1,
    );

    my $dbh = DBI->connect($dsn, $conf->{'db_user'}, $conf->{'db_pass'}, \%attr);

    return $dbh;
}

1;
