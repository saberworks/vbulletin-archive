#!/usr/bin/perl

use warnings;
use strict;

use feature qw/say/;

use local::lib;

use Data::Dumper;
use Devel::Size qw(total_size);
use JSON;

use VBI::Forum;
use VBI::JsonDump;
use VBI::Util qw/create_dir directory_is_valid slugify/;

my $conf = VBI::Conf::get();

my $style_id = $conf->{'style_id'};
my $json_dir = $conf->{'json_dir'};
my $html_dir = $conf->{'html_dir'};

if(!directory_is_valid($json_dir)) {
    die "Please create the json_dir as specified in config.conf: $json_dir";
}

if(!directory_is_valid($html_dir)) {
    die "Please create the html_dir as specified in config.conf: $html_dir";
}

my $parents = VBI::Forum::get_parents();
my $forums = VBI::Forum::get_forums();

# Generate and add a "slug" based on category/forum title.
add_slug($parents, 'title');
add_slug($forums, 'title');

VBI::JsonDump::dump_json($json_dir, "forum_categories.json", $parents);
VBI::JsonDump::dump_json($json_dir, "forums.json", $forums);

my $attachments_dir = create_dir($html_dir, "attachments");

my $attachments_by_post = dump_all_attachments($attachments_dir);

warn "SIZE in memory of attachments list:";
warn total_size($attachments_by_post);

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

            say "\tprocessing thread $thread_id (" . $thread->{'title'} . ")";

            my $posts = VBI::Forum::get_posts($thread_id, $style_id);

            my $posts_file = sprintf($posts_file_fmt, $forum_id, $thread_id);

            foreach my $post (@$posts) {
                my $post_id = $post->{'postid'};

                my $attachments = $attachments_by_post->{$post_id};

                $post->{'attachments'} = $attachments;
            }

            VBI::JsonDump::dump_json($forum_dir, $posts_file, $posts);

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

sub dump_all_attachments {
    my $attachments_dir = shift;

    my $sth = VBI::Forum::get_all_attachments();

    my $attachments_by_post = {};

    while(my $row = $sth->fetchrow_hashref()) {
        my $post_id = $row->{'postid'};
        my $attachment_id = $row->{'attachmentid'};

        # TODO: figure out correct filenames to write attachments
        # and thumbnail files (which are currently not being output
        # at all!)
        my $filedata = delete $row->{'filedata'};
        my $thumbnail = delete $row->{'thumbnail'};

        # program will die if this create_dir fails
        my $dir = create_dir($attachments_dir, $attachment_id);

        my $relative_filename = sprintf('%d/%s', $attachment_id, $row->{'filename'});

        my $filepath = join(
            '/', $attachments_dir, $relative_filename
        );

        open my $fh, '>', $filepath or die "Couldn't open $filepath for writing: $!";
        print $fh $filedata;
        close $fh;

        $row->{'filename'} = $relative_filename;

        push @{$attachments_by_post->{$post_id}}, $row;
    }

    return $attachments_by_post;
}
