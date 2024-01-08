#!/usr/bin/perl

use warnings;
use strict;

use feature qw/say/;

use local::lib;

use Data::Dumper;
use JSON;

use VBI::Forum;
use VBI::JsonDump;
use VBI::Util qw/create_dir directory_is_valid slugify/;

my $conf = VBI::Conf::get();

my $style_id = $conf->{'style_id'};
my $json_dir = $conf->{'json_dir'};

if(!directory_is_valid($json_dir)) {
    die "Please create the json_dir as specified in config.conf: $json_dir";
}

my @wanted_threads = @ARGV;

my $parents = VBI::Forum::get_parents();
my $forums = VBI::Forum::get_forums();

# Generate and add a "slug" based on category/forum title.
add_slug($parents, 'title');
add_slug($forums, 'title');

VBI::JsonDump::dump_json($json_dir, "forum_categories.json", $parents);
VBI::JsonDump::dump_json($json_dir, "forums.json", $forums);

my $attachments_dir = create_dir($json_dir, "attachments");

foreach my $parent (@$parents) {
    say $parent->{'title'};

    my $category_slug = $parent->{'slug'};;
    my $category_dir = create_dir($json_dir, $category_slug);

    my $threadlist_fmt = 'forum_%d_thread_list.json';
    my $posts_file_fmt = 'forum_%d_thread_%d.json';

    foreach my $forum (@$forums) {
        next unless $forum->{'parentid'} == $parent->{'forumid'};

        my $forum_id = $forum->{'forumid'};
        my $forum_slug = $forum->{'slug'};

        my $forum_dir = create_dir($category_dir, $forum_slug);

        say "\t" . $forum->{'title'};

        my $threads = VBI::Forum::get_threads($forum_id);

        my $threadlist_file = sprintf($threadlist_fmt, $forum_id);

        VBI::JsonDump::dump_json($forum_dir, $threadlist_file, $threads);

        foreach my $thread (@$threads) {
            my $thread_id = $thread->{'threadid'};

            my $posts = VBI::Forum::get_posts($thread_id, $style_id);

            if(@wanted_threads) {
                if(grep( /^$thread_id$/, @wanted_threads ) ) {
                    warn "found it";
                    warn Dumper $thread;
                    warn Dumper $posts;
                }
                else {
                    next;
                }
            }

            my $posts_file = sprintf($posts_file_fmt, $forum_id, $thread_id);

            VBI::JsonDump::dump_json($forum_dir, $posts_file, $posts);

            foreach my $post (@$posts) {
                my $post_id = $post->{'postid'};

                my $attachments = VBI::Forum::get_attachments($post_id);

                # TODO: figure out correct filenames to write attachments
                # and thumbnail files (which are currently not being output
                # at all!)
                foreach my $attachment (@$attachments) {
                    my $filedata = delete $attachment->{'filedata'};
                    my $thumbnail = delete $attachment->{'thumbnail'};

                    my $filename = sprintf(
                        '%d.%s',
                        $attachment->{'attachmentid'},
                        $attachment->{'extension'}
                    );

                    my $filepath = "$attachments_dir/$filename";

                    open my $fh, '>', $filepath or die "Couldn't open $filepath for writing: $!";
                    print $fh $filedata;
                    close $fh;

                    # warn "wrote $filepath\n";
                }
            }
        }
    }
}

sub add_slug {
    my ($ref, $key) = @_;

    foreach my $item (@$ref) {
        if(!$item->{$key}) {
            die "Unable to find $key in $ref, so unable to slugify";
        }

        $item->{'slug'} = slugify($item->{$key});
    }
}
