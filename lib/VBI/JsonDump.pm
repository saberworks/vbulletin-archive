package VBI::JsonDump;

use warnings;
use strict;

use local::lib;

use JSON;

sub dump_json {
    my ($dir, $filename, $data) = @_;

    my $json = JSON->new->utf8(1)->pretty(1)->encode($data);

    open my $fh, '>', "$dir/$filename"
        or die "Unable to open file: $dir/$filename: $@";

    print $fh $json;

    close $fh;

}

1;
