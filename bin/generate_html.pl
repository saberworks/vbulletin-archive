#!/usr/bin/perl

use warnings;
use strict;

use feature qw/say/;

use local::lib;

use Data::Dumper;
use File::Slurp qw/read_file/;
use Template;
use JSON;

use VBI::Conf;
use VBI::Util qw/create_dir/;

my $conf = VBI::Conf::get();

my $json_dir = $conf->{'json_dir'};
my $html_dir = $conf->{'html_dir'};
my $tmpl_dir = $conf->{'tmpl_dir'};

warn Dumper($conf);
warn "TMPL DIR: $tmpl_dir";

my $unsorted_categories = parse_json($json_dir, "forum_categories.json");
my $unsorted_forums = parse_json($json_dir, "forums.json");

my $categories = [sort by_displayorder @$unsorted_categories];
my $forums     = [sort by_displayorder @$unsorted_forums];

my $index_file = generate_index_file($tmpl_dir, $categories, $forums, $html_dir);

foreach my $cat (sort by_displayorder @$categories) {
    say "Processing category " . $cat->{'title'};

    my $category_slug = $cat->{'slug'};
    my $category_json_dir = "$json_dir/$category_slug";

    my $category_html_dir = create_dir($html_dir, $category_slug)
        or die "Unable to create $category_slug: $!";

    foreach my $forum (sort by_displayorder @$forums) {
        next unless $forum->{'parentid'} == $cat->{'forumid'};

        say "\tProcessing forum " . $forum->{'title'};

        my $forum_slug = $forum->{'slug'};
        my $forum_json_dir = "$category_json_dir/$forum_slug";

        my $forum_html_dir = create_dir($category_html_dir, $forum_slug)
            or die "Unable to create $forum_slug: $!";

        my $forum_id = $forum->{'forumid'};

        my $threads = parse_json($forum_json_dir, sprintf("forum_%d_thread_list.json", $forum_id));

        my $forum_index_file = generate_forum_index($cat, $forum, $threads, $forum_html_dir);

        foreach my $thread (@$threads) {
            generate_thread($cat, $forum, $thread, $forum_html_dir);
        }

        # TODO
        # Generate apache redirects ?? or nginx redirects ?? to maintain old
        # urls
    }
}


sub parse_json {
    my ($dir, $file) = @_;

    my $json = read_file($dir . "/" . $file);

    return decode_json($json);
}

sub by_displayorder {
    return $a->{'displayorder'} <=> $b->{'displayorder'};
}

sub generate_index_file {
    my ($tmpl_dir, $categories, $forums, $html_dir) = @_;

    # my $index_tmpl = $tmpl_dir . "/index.html";
    my $index_file = $html_dir . "/index.html";

    my $template = Template->new(
        INCLUDE_PATH => $tmpl_dir,
        WRAPPER => 'outer.html',
    );

    my $params = {
        categories => $categories,
        forums => $forums,
    };

    $template->process("index.html", $params, $index_file)
        or die "Template processing failed for 'index.html': " . $template->error();

    return $index_file;
}

sub generate_forum_index {
    my ($cat, $forum, $threads, $forum_html_dir) = @_;

    # my $forum_index_tmpl = $tmpl_dir . "/forum.html";
    my $forum_index_file = $forum_html_dir . "/index.html";

    my $template = Template->new(
        INCLUDE_PATH => $tmpl_dir,
        WRAPPER => 'outer.html',
    );

    my $params = {
        category => $cat,
        forum => $forum,
        threads => $threads,
    };

    $template->process("forum.html", $params, $forum_index_file)
        or die "Template processing failed for 'forum.html': " . $template->error();

    return $forum_index_file;
    # return $index_file;

    # open my $fh, '>', $forum_index_file
    #     or die "Unable to open $forum_index_file: $!";

    # foreach my $thread (@$threads) {
    #     my $title = $thread->{'title'};
    #     my $replies = $thread->{'replycount'};
    #     say $fh "<p>$title ($replies replies)</p>";
    #     generate_thread($cat, $forum, $thread, $forum_html_dir);
    # }

    # close $fh;

    # return $forum_index_file;
}

# TODO
sub generate_thread {
    my ($cat, $forum, $thread, $forum_html_dir) = @_;
    return;
}
