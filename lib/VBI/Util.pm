package VBI::Util;

use warnings;
use strict;

use parent 'Exporter';

our @EXPORT_OK = qw(create_dir directory_is_valid slugify);

sub create_dir {
    my ($parent_dir, $new_dir) = @_;

    my $dir = "$parent_dir/$new_dir";

    if(!-d $dir) {
        mkdir $dir or die $!;
    }

    return $dir;
}

sub directory_is_valid {
    my $dir = shift;

    if(! -d $dir) {
        warn "$dir does not exist\n";

        return 0;
    }

    if(! -w $dir) {
        warn "$dir exists but not writable by current user, please check permissions\n";

        return 0;
    }

    return 1;
}

sub slugify {
    my $title = shift;

    $title =~ s/ /_/g;

    return $title;
}

1;
