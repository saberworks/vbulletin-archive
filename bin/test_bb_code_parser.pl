#!/usr/bin/perl

use warnings;
use strict;

use feature qw/say/;

use local::lib;

use Data::Dumper;
use File::Slurp qw/read_file/;
use JSON;
use List::Util qw(first);
use Template;

use VBI::BBCode;

my $posts = [];

my @tests = (
    "[quote=foo;1234]quoted text[/quote]",
    "[quote=foo bar;1234]quoted text[/quote]",
    "[quote]quoted text[/quote]",
    '[quote=foo]quoted text[/quote]',
    '[spoiler]foo[/spoiler]',
    '[spoilerbox]foo[/spoilerbox]',
    '[code]some code < >[/code]',
    '[FONT=Century Gothic]frametime[/FONT]',
    '[FONT=verdana]frametime[/FONT]',
    '[code]


    some code
    if(foo) {
        bar;
    }


    [/code]',
);

foreach my $test (@tests) {
    say $test;
    say _parse_bbcode($test, $posts);
    say "";
}

sub _parse_bbcode {
    my ($code, $posts) = @_;

    my $parser = VBI::BBCode->new($posts);

    my $rendered = $parser->render($code);

    return $rendered;
}
