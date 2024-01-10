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
use VBI::Conf;
use VBI::Util qw/create_dir/;

my $conf = VBI::Conf::get();

my $json_dir = $conf->{'json_dir'};
my $html_dir = $conf->{'html_dir'};
my $tmpl_dir = $conf->{'tmpl_dir'};

warn Dumper($conf);
warn "TMPL DIR: $tmpl_dir";

copy_smileys($conf->{'smileys_dir'}, $html_dir, '/smileys');
copy_css('css', $html_dir);

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
            my $thread_id = $thread->{'threadid'};

            my $thread_json_file = sprintf("forum_%d_thread_%d.json", $forum_id, $thread_id);

            # Apparently we have some threads in the index that don't have any
            # posts?  wth?
            next unless -f "$forum_json_dir/$thread_json_file";

            my $posts = parse_json($forum_json_dir, $thread_json_file);

            generate_thread($cat, $forum, $thread, $posts, $forum_html_dir);
        }

        # TODO
        # Generate apache redirects ?? or nginx redirects ?? to maintain old
        # urls
    }
}

sub parse_json {
    my ($dir, $file) = @_;

    my $json;

    eval {
        $json = read_file($dir . "/" . $file);
    };

    if(my $error = $@) {
        warn "Unable to read $dir/$file, SKIPPING.  $error";
        return;
    }

    return decode_json($json);
}

sub by_displayorder {
    return $a->{'displayorder'} <=> $b->{'displayorder'};
}

sub generate_index_file {
    my ($tmpl_dir, $categories, $forums, $html_dir) = @_;

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
}

sub generate_thread {
    my ($cat, $forum, $thread, $posts, $forum_html_dir) = @_;

    parse_bbcode($posts, 'pagetext', 'post_html');

    my $thread_id = $thread->{'threadid'};

    my $thread_file = $forum_html_dir . '/' . $thread_id . '.html';

    my $template = Template->new(
        INCLUDE_PATH => $tmpl_dir,
        WRAPPER => 'outer.html',
    );

    my $params = {
        category => $cat,
        forum => $forum,
        thread => $thread,
        posts => $posts,
    };

    $template->process("thread.html", $params, $thread_file)
        or die "Template processing failed for 'thread.html': " . $template->error();

    return $thread_file;
}

#
# $source_key is the key in the $post that contains the user's unparsed input
#
# $output_key is the key in the $post which will contain the _parsed_ input
#             after this function has run
sub parse_bbcode {
    my ($posts, $source_key, $output_key) = @_;

    foreach my $post (@$posts) {
        if(!$post->{$source_key}) {
            my $post_id = $post->{'postid'};
            warn "Unable to find $source_key in $post_id, so unable to parse bb code, SKIPPING";
            $post->{$output_key} = $post->{$source_key};
            next;
        }

        $post->{$output_key} = _parse_bbcode($post->{$source_key}, $posts);
    }
}

sub _parse_bbcode {
    my ($code, $posts) = @_;

    my $parser = VBI::BBCode->new($posts);

    my $rendered = $parser->render($code);

    return $rendered;
}

sub copy_smileys {
    my ($source_dir, $html_dir, $smilies_dir) = @_;

    my $destination_dir = create_dir($html_dir, $smilies_dir);

    system("cp $source_dir/* $destination_dir/") == 0
        or die "copying smileys failed: $?";
}

sub copy_css {
    my ($source_dir, $html_dir) = @_;

    my $destination_dir = create_dir($html_dir, 'css');

    system("cp $source_dir/* $destination_dir") == 0
        or die "copying css failed: $?";
}
