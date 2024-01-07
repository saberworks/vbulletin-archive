#!/usr/bin/perl

use warnings;
use strict;

use feature qw/say/;

use local::lib;

use Data::Dumper;
use JSON;

use VBI::Forum;
use VBI::JsonDump;
use VBI::Util qw/serialize_title/;

my $conf = VBI::Conf::get();

my $json_dir = $conf->{'json_dir'};

my $parents = VBI::Forum::get_parents();
my $forums = VBI::Forum::get_forums();

VBI::JsonDump::dump_json($json_dir, "forum_categories.json", $parents);
VBI::JsonDump::dump_json($json_dir, "forums.json", $forums);

#my $attachments_dir = "$json_dir/attachments";

my $attachments_dir = create_slug_dir($json_dir, "attachments");

# Print a list of categories and forums, in the proper order
foreach my $parent (@$parents) {
    say $parent->{'title'};

    my $category_slug = serialize_title($parent->{'title'});
    my $category_dir = create_slug_dir($json_dir, $category_slug);

    my $threadlist_fmt = 'forum_%d_thread_list.json';
    my $posts_file_fmt = 'forum_%d_thread_%d.json';

    foreach my $forum (@$forums) {
        next unless $forum->{'parentid'} == $parent->{'forumid'};

        my $forum_id = $forum->{'forumid'};
        my $forum_slug = serialize_title($forum->{'title'});
        my $forum_dir = create_slug_dir($category_dir, $forum_slug);

        say "\t" . $forum->{'title'};

        my $threads = VBI::Forum::get_threads($forum_id);

        my $threadlist_file = sprintf($threadlist_fmt, $forum_id);

        VBI::JsonDump::dump_json($forum_dir, $threadlist_file, $threads);

        foreach my $thread (@$threads) {
            my $thread_id = $thread->{'threadid'};

            my $posts = VBI::Forum::get_posts($thread_id);

            my $posts_file = sprintf($posts_file_fmt, $forum_id, $thread_id);

            VBI::JsonDump::dump_json($forum_dir, $posts_file, $posts);

            foreach my $post (@$posts) {
                my $post_id = $post->{'postid'};

                my $attachments = VBI::Forum::get_attachments($post_id);

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

                    warn "wrote $filepath\n";
                }
            }
        }
    }
}

sub create_slug_dir {
    my ($parent_dir, $slug) = @_;

    my $dir = "$parent_dir/$slug";

    if(!-d $dir) {
        mkdir $dir or die $!;
    }

    return $dir;
}
