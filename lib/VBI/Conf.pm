package VBI::Conf;

use warnings;
use strict;

use local::lib;

use Config::Fast;
use Cwd;
use Data::Dumper;
use FindBin qw($Bin);

sub get {
    my %cf = fastconfig("$Bin/../etc/config.conf");

    foreach my $key (keys %cf) {
        if($key =~ /_dir$/ && $key !~ /^tmpl/) {
            my $value = $cf{$key};

            $cf{$key} = Cwd::realpath("$Bin/../$value");
        }

        if($key eq 'copy_dirs') {
            my $value = $cf{$key};

            my @dirs = split /, /, $value;

            $cf{$key} = \@dirs;
        }
    }

    return \%cf;
}

1;
