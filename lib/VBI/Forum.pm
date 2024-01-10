package VBI::Forum;

use warnings;
use strict;

use local::lib;

use Data::Dumper;

use VBI::Db;

my $dbh = VBI::Db::get();

my $HARD_LIMIT = 99999999;

sub get_forums {
    my $q = q{
        SELECT forumid, title, description, parentid, displayorder,
               replycount, threadcount
          FROM forum
         WHERE forumid IN(8, 14, 29, 9, 12, 11, 24)
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

    my $q = qq{
        SELECT *
          FROM thread
         WHERE forumid = ?
           AND visible = 1
      ORDER BY lastpost DESC
         LIMIT $HARD_LIMIT
    };

    return $dbh->selectall_arrayref($q, { Slice => {} }, $forum_id);
}

sub get_posts {
    my ($thread_id, $style_id) = @_;

    my $q = qq{
        SELECT p.postid, p.threadid, p.username, p.userid, p.title, p.dateline,
               p.pagetext, pp.pagetext_html,
               p.allowsmilie, p.showsignature, p.iconid, p.visible, p.parentid,
               p.htmlstate, pp.hasimages, pp.dateline as parsed_dateline,
               u.usertitle, u.posts, sp.signatureparsed
          FROM post p
          JOIN user u ON p.userid = u.userid
     LEFT JOIN sigparsed sp ON (u.userid = sp.userid AND sp.styleid = ?)
     LEFT JOIN postparsed pp ON (p.postid = pp.postid AND pp.styleid = ?)
         WHERE threadid = ?
           AND visible = 1
      ORDER BY dateline ASC
         LIMIT $HARD_LIMIT
    };

    return $dbh->selectall_arrayref(
        $q, { Slice => {} }, $style_id, $style_id, $thread_id
    );
}

sub get_attachments {
    my $post_id = shift;

    my $q = qq{
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
       LIMIT $HARD_LIMIT
    };

    return $dbh->selectall_arrayref($q, { Slice => {} }, $post_id);
}

# This returns a statement handle to get results rather than a list of results
# (different than all the other functions in this package).
#
# Returns all valid/public/visible attachments.  Intention is for these to be
# dumped to filesystem ahead of time and no more need to look up attachments
# on a per-post basis (was taking too long).
sub get_all_attachments {
    my $q = qq{
      SELECT a.attachmentid, a.contentid as postid, a.filename,
             a.caption, a.displayorder, a.settings,
             p.threadid,
             fd.filedata,
             fd.thumbnail,
             fd.filesize, fd.extension,
             fd.width, fd.height, fd.thumbnail_width, fd.thumbnail_height
        FROM attachment a, post p, filedata fd
       WHERE a.contentid = p.postid
         AND a.filedataid = fd.filedataid
         AND contenttypeid = 1
         AND state = 'visible'
    ORDER BY a.attachmentid
       LIMIT 99999999999
    };

    my $sth = $dbh->prepare($q);

    $sth->execute() or die "Unable to get_all_attachments()";

    return $sth;
}

1;
