#!/usr/bin/perl

use warnings;
use strict;

use feature qw/say/;

use local::lib;

use Data::Dumper;
use File::Slurp qw/read_file/;
use JSON;
use List::Util qw(first);
use Parse::BBCode;
use Template;

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
            my $thread_id = $thread->{'threadid'};

            my $thread_json_file = sprintf("forum_%d_thread_%d.json", $forum_id, $thread_id);
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

    my $json = read_file($dir . "/" . $file);

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

sub parse_bbcode {
    my ($posts, $source_key, $output_key) = @_;

    foreach my $post (@$posts) {
        if(!$post->{$source_key}) {
            die "Unable to find $source_key in $post, so unable to parse bb code";
        }

        $post->{$output_key} = _parse_bbcode($post->{$source_key}, $posts);
    }
}

sub _parse_bbcode {
    my ($code, $posts) = @_;

    my $p = Parse::BBCode->new({
        tags => {
            # load the default tags
            Parse::BBCode::HTML->defaults,

            # add/override tags
            'quote' => {
                code => sub {
                    my ($parser, $attr, $content) = @_;
                    my $title = 'Quote';
                    if ($attr) {
                        $attr =~ s/;\d+$//; # remove user id from end of attr
                        $title = "Originally posted by <strong>" . Parse::BBCode::escape_html($attr) . "</strong>";
                    }
                    return qq{
                        <div class="bbcode_quote_header">$title:
                        <div class="bbcode_quote_body">$$content</div></div>
                    };
                },
                parse => 1,
                class => 'block',
            },
            'attach' => {
                code => sub {
                    # example: [ATTACH=CONFIG]29010[/ATTACH]
                    # TODO: Probably have to examine attachment->extension and
                    # render things like zips differently :( argh
                    my ($parser, $attr, $content) = @_;
                    if ($attr) {
                        # is it always "CONFIG"???
                    }
                    my $a = find_attachment($posts, $$content);
                    # Todo put the image dimensions in the html, and maybe do thumbnail?
                    my ($filename, $width, $height, $thumbnail_width, $thumbnail_height) = $a->{'filename'};
                    return qq{
                        <div class="attached_image">
                            <img src="../../attachments/$filename">
                        </div>
                    };
                },
                parse => 1,
                class => 'block',
            },
            'flipthis' => {
                code => sub {
                    # example: [flipthis]<someurl>[/flipthis]
                    my ($parser, $attr, $content) = @_;
                    return qq{
                        (╯°□°)╯︵<img src="$$content" style=" -moz-transform: rotate(180deg); -o-transform: rotate(180deg); -webkit-transform: rotate(180deg); transform: rotate(180deg); filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=2); " />
                    };
                },
                parse => 1,
                class => 'block',
            },
            'youtube' => {
                code => sub {
                    # example: [youtube]q-wGMlSuX_c[/youtube]
                    my ($parser, $attr, $content) = @_;
                    return qq{
                        <iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/$$content?rel=0" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
                    };
                },
                parse => 1,
                class => 'block',
            },
            'video' => {
                code => sub {
                    # example: [video=youtube;q-wGMlSuX_c]https://www.youtube.com/watch?v=OFsN97cxI-c[/youtube]
                    my ($parser, $attr, $content) = @_;
                    if($attr =~ /^youtube;/i) {
                        $attr =~ s/^youtube;//;
                    }
                    else {
                        return "Sorry, don't know how to play $attr videos :(";
                    }
                    return qq{
                        <iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/$attr?rel=0" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
                    };
                },
                parse => 1,
                class => 'block',
            },
        }
    });

    my $rendered = $p->render($code);

    return $rendered;
}

sub find_attachment {
    my ($posts, $attachment_id) = @_;

    foreach my $post (@$posts) {
        my $attachments = $post->{'attachments'};

        if(my ($matched) = grep { $_->{'attachmentid'} eq $attachment_id } @$attachments) {
            return $matched;
        }
    }
}
