#!/usr/bin/perl

use warnings;
use strict;

use feature qw/say/;

use local::lib;

use Data::Dumper;
use File::Slurp qw/read_file/;
use JSON;
use List::Util qw/first/;
use Storable qw/dclone/;
use Template;

use VBI::BBCode;
use VBI::Conf;
use VBI::Util qw/create_dir/;

# Make template::toolkit format plugin stfu
$SIG{'__WARN__'} = sub {
    warn $_[0] unless (
        caller eq "Template::Plugin::Format" && $_[0] =~ /^Redundant/
    );
};

my $conf = VBI::Conf::get();

my $json_dir = $conf->{'json_dir'};
my $html_dir = $conf->{'html_dir'};
my $tmpl_dir = $conf->{'tmpl_dir'};

warn Dumper($conf);

# $redirect_fh must remain in global context for now since there are some
# functions that depend on it.
# TODO: get rid of the global fh
my $redirect_fh = create_redirect_file("$html_dir/nginx_redirects.conf");

# In conf, you can specify a bunch of directories that will be copied from
# src/<dir> to <html_dir>/<dir>.  This is useful for smilies, css, images,
# or any other arbitrary directory (in massassi's case, there was an html/
# directory that had images that were commonly linked to).
foreach my $dir (@{$conf->{'copy_dirs'}}) {
    copy_dir($dir, $html_dir);
}

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

        generate_forum_index($cat, $forum, $threads, $forum_html_dir);
        generate_redirects($cat, $forum, $threads);

        foreach my $thread (@$threads) {
            my $thread_id = $thread->{'threadid'};

            my $thread_json_file = sprintf("forum_%d_thread_%d.json", $forum_id, $thread_id);

            # Apparently we have some threads in the index that don't have any
            # posts?  wth?
            next unless -f "$forum_json_dir/$thread_json_file";

            my $posts = parse_json($forum_json_dir, $thread_json_file);

            generate_thread($cat, $forum, $thread, $posts, $forum_html_dir);
        }
    }
}

end_redirect_file();

sub generate_redirects {
    my ($cat, $forum, $threads) = @_;

    my $category_slug = $cat->{'slug'};
    my $forum_id = $forum->{'forumid'};
    my $forum_slug = $forum->{'slug'};

    my $rule = qq[~^/vb3/forumdisplay\\.php\\?${forum_id}-(.*)\$  /${category_slug}/${forum_slug}/index.html;];

    add_redirect_rule($rule);

    my $thread_rule_fmt = qq[~^/vb3/showthread\\.php\\?%d-(.*)\$ /%s/%s/thread_%d_page_1.html;];

    foreach my $thread (@$threads) {
        my $thread_id = $thread->{'threadid'};

        add_redirect_rule(
            sprintf($thread_rule_fmt, $thread_id, $category_slug, $forum_slug, $thread_id)
        );
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

    my $thread_list_page_size = $conf->{'thread_list_page_size'};

    my $threads_copy = dclone($threads);

    my $forum_id = $forum->{'forumid'};

    my $forum_index_file = "index.html";
    my $paged_file_fmt = "forum_${forum_id}_page_%d.html";

    my @paged_threads;

    # split thread list into chunks of $thread_list_page_size for paging
    while (my @next_100 = splice @$threads_copy, 0, $thread_list_page_size) {
        push @paged_threads, \@next_100;
    }

    my $num_pages = @paged_threads;

    for(my $i = 0; $i < @paged_threads; $i++) {
        my $page_number = $i + 1;

        my $current_file = $page_number == 1
                         ? "$forum_html_dir/$forum_index_file"
                         : $forum_html_dir . '/' . sprintf($paged_file_fmt, $page_number);

        my $template = Template->new(
            INCLUDE_PATH => $tmpl_dir,
            WRAPPER => 'outer.html',
        );

        my $params = {
            category => $cat,
            forum => $forum,
            threads => $paged_threads[$i],
            first_page_link_fmt => $forum_index_file,
            page_link_fmt => $paged_file_fmt,
            number_of_pages => $num_pages,
            current_page_number => $page_number,
        };

        $template->process("forum.html", $params, $current_file)
            or die "Template processing failed for 'forum.html': " . $template->error();
    }

    return;
}

sub generate_thread {
    my ($cat, $forum, $thread, $posts, $forum_html_dir) = @_;

    my $thread_page_size = $conf->{'thread_page_size'};

    parse_bbcode($posts, 'pagetext', 'post_html');

    my $thread_id = $thread->{'threadid'};
    my $forum_id = $forum->{'forumid'};

    my $thread_file_fmt = "thread_${thread_id}_page_%d.html";

    my $posts_copy = dclone($posts);

    my @paged_posts;

    # split post list into chunks of $thread_page_size for paging
    while (my @next_n = splice @$posts_copy, 0, $thread_page_size) {
        push @paged_posts, \@next_n;
    }

    my $num_pages = @paged_posts;

    for(my $i = 0; $i < @paged_posts; $i++) {
        my $page_number = $i + 1;

        my $current_file = $forum_html_dir . '/' . sprintf($thread_file_fmt, $page_number);

        my $template = Template->new(
            INCLUDE_PATH => $tmpl_dir,
            WRAPPER => 'outer.html',
        );

        my $params = {
            category => $cat,
            forum => $forum,
            thread => $thread,
            posts => $paged_posts[$i],
            first_page_link_fmt => $thread_file_fmt,
            page_link_fmt => $thread_file_fmt,
            number_of_pages => $num_pages,
            current_page_number => $page_number,
            thread_page_size => $thread_page_size,
        };

        $template->process("thread.html", $params, $current_file)
            or die "Template processing failed for 'thread.html': " . $template->error();

        # set the file create and modified time to the original thread time
        my $last_post_timestamp = $thread->{'lastpost'};
        utime($last_post_timestamp, $last_post_timestamp, $current_file) ||
            warn "Unable to set created/modified timestamp on $current_file: $!";
    }

    return 1;
}

#
# $source_key is the key in the $post that contains the user's unparsed input
#
# $output_key is the key in the $post which will contain the _parsed_ input
#             after this function has run
#
sub parse_bbcode {
    my ($posts, $source_key, $output_key) = @_;

    foreach my $post (@$posts) {
        if(!$post->{$source_key}) {
            my $post_id = $post->{'postid'};
            warn "\t\tUnable to find $source_key in $post_id, so unable to parse bb code";
            $post->{$output_key} = "The content of this post is missing.";
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

sub copy_dir {
    my ($source_dir, $html_dir) = @_;

    my $destination_dir = create_dir($html_dir, $source_dir);

    system("cp -r $source_dir/* $destination_dir") == 0
        or die "copying $source_dir failed: $?";
}

# returns a file handle that must be added to global scope :(
sub create_redirect_file {
    my $path = shift;

    open my $fh, '>', $path or die "Unable to open redirect file ($path): $!";

    say $fh qq[map \$request_uri \$redirect {];
    say $fh qq[    /vb3/ /index.html;];
    say $fh qq[    /vb3 /index.html;];
    say $fh qq[    / /index.html;];

    return $fh;
}

# adds a redirect rule to the global $redirect_fh handle :(
sub add_redirect_rule {
    my $rule = shift;

    say $redirect_fh "    " . $rule;
}

# closes the global $redirect_fh handle :(
sub end_redirect_file {
    say $redirect_fh "}";
    close $redirect_fh;
}
