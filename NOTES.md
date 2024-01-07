# post cache

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
