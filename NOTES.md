# TODO TODO TODO



- paging? to be worth it would need to happen on the thread list and on
  individual threads

- output a set of redirect rules for apache or nginx so old URLs can be
  redirected to the archive


## redirect notes

These are the urls that must be redirected:

* /vb3/ -> /
* /vb3/forumdisplay.php?8-Discussion-Forum -> /Main_Massassi_Forums/Discussion_Forum/index.html
    * (for all forums)
* /vb3/showthread.php?68318-Happy-New-Years!! -> /Main_Massassi_Forums/Discussion_Forum/68318.html
    * (for all threads)
* /vb3/forumdisplay.php?f=14 -> /Main_Massassi_Forums/Interactive_Story_Board/index.html
    * (for all forums)

Note: only the ?<number> parts are important for redirect matches, the crap
that comes after the number is solely for google juice.  Don't need to match
on it, just the id

# FIXED

- some [code] tags not working right (wasn't going to fix but it's affecting
  the entire cog forum so needs to be fixed)
- add "go to top" link to bottom of every page
- [spoiler] tags not working at all
- [quote] with space in name like [quote=Foo Bar:12345] (breaks Parse::BBCode)
- fix slow export
- images in custom user titles are broken



# post cache

Note: ended up not using postparsed, just doing all the parsing myself, so all
the stuff below doesn't matter.

Problem: text in the `post` table has raw bb code.  It would be nice to get
vbulletin to parse/interpolate the bb code into real HTML before export.

Possible solution: the `postparsed` table has parsed/interpolated text.
However, there aren't rows for every post.

Possible solution: modify vbulletin settings to save the post cache going back
to the beginning of the forums (I did 20 years worth of days just to be safe).
Now postparsed contains rows for every post.

Problem: `postparsed` text has `hasimages` column and when it's set to `1` it
means there are unparsed [IMG] tags in the body.  Not sure why they leave some
unparsed; need to actually implement a solution to parse/interpolate these.

Problem: After regenerating post cache with maximum look back days, the
`postparsed` table still has fewer rows than the `post` table:

mysql> select count(*) from postparsed where styleid=33;
+----------+
| count(*) |
+----------+
|  1056188 |
+----------+
1 row in set (0.00 sec)

mysql> select count(*) from post;
+----------+
| count(*) |
+----------+
|  1216492 |
+----------+
1 row in set (0.00 sec)

So during the html generation process, I have to check for postparsed, and if
it's not there, inspect the stuff in the actual post and see why it might not
get parsed.  Maybe they're orphan posts or deleted posts or something.

select * from post p
left join postparsed pp on p.postid=pp.postid
WHERE p.threadid=99
AND pp.styleid=33

select * from post p
join postparsed pp on p.postid=pp.postid
WHERE p.threadid=99
AND pp.styleid=33

select min(postid) from post;
select min(postid) from postparsed;

select postid, hasimages, pagetext_html from postparsed where styleid=3 and hasimages=1 limit 10

select count(*) from postparsed where styleid=33;
select count(*) from post;

IMG tags appear to not be interpolated
