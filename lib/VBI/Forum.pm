package VBI::Forum;

use warnings;
use strict;

use local::lib;

use Data::Dumper;

use VBI::Db;

my $dbh = VBI::Db::get();

sub get_forums {
    my $q = q{
        SELECT forumid, title, description, parentid, displayorder,
               replycount, threadcount
          FROM forum
         WHERE forumid IN( 8, 14, 29, 9, 12, 11, 24)
           AND displayorder != 0
         ORDER BY parentid, displayorder, title, description
    };

    return $dbh->selectall_arrayref($q, { Slice => {} });
}

sub get_parents {
    my $q = q{
        SELECT forumid, title, displayorder
          FROM forum
         WHERE forumid IN (3, 4)
           AND parentid = -1
      ORDER BY displayorder
    };

    return $dbh->selectall_arrayref($q, { Slice => {} });
}

sub get_threads {
    my $forum_id = shift;

    my $q = q{
        SELECT *
          FROM thread
         WHERE forumid = ?
           AND visible = 1
      ORDER BY lastpost DESC
         LIMIT 999999999
    };

    return $dbh->selectall_arrayref($q, { Slice => {} }, $forum_id);
}

sub get_posts {
    my $thread_id = shift;

    my $q = q{
        SELECT p.postid, p.threadid, p.username, p.userid, p.title, p.dateline,
               p.pagetext, pp.pagetext_html,
               p.allowsmilie, p.showsignature, p.iconid, p.visible, p.parentid,
               p.htmlstate
          FROM post p
          JOIN postparsed pp ON p.postid = pp.postid
         WHERE threadid = ?
           AND visible = 1
      ORDER BY dateline ASC
         LIMIT 999999999
    };

    return $dbh->selectall_arrayref($q, { Slice => {} }, $thread_id);
}

sub get_attachments {
    my $post_id = shift;

    my $q = q{
      SELECT a.attachmentid, a.contentid as postid, a.filename,
             a.caption, a.displayorder, a.settings,
             p.threadid,
             fd.filedata, fd.thumbnail, fd.filesize, fd.extension,
             fd.width, fd.height, fd.thumbnail_width, fd.thumbnail_height
        FROM attachment a, post p, filedata fd
       WHERE p.postid = ?
         AND a.contentid = p.postid
         AND a.filedataid = fd.filedataid
         AND contenttypeid = 1
         AND state = 'visible'
    ORDER BY a.attachmentid
       LIMIT 999999999
    };

    return $dbh->selectall_arrayref($q, { Slice => {} }, $post_id);
}

1;
