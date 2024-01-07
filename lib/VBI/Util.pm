package VBI::Util;

use warnings;
use strict;

use parent 'Exporter';

our @EXPORT_OK = qw(create_dir serialize_title);

sub serialize_title {
    my $title = shift;

    $title =~ s/ /_/g;

    return $title;
}

sub create_dir {
    my ($parent_dir, $new_dir) = @_;

    my $dir = "$parent_dir/$new_dir";

    if(!-d $dir) {
        mkdir $dir or die $!;
    }

    return $dir;
}

1;
