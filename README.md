# Notes by date

## 2024-01-02

- look in `postparsed` table, it looks like it has html-version of all the posts,
so I don't have to interpret bb code at all

## 2024-01-06

Got the main forum list page generated and looking pretty good.

# What the hell is this?

This is a code dump of what I'm working on archive my vBulletin v4.2.3 forums.
There is no included tool that will let me archive everything to static pages.
My forums aren't being used much anymore and they're running old php, old
vbulletin, and old operating system.  I didn't want to pay for a license
to the new version and continue to maintain forums that aren't being used
anymore.

Hopefully this will help you.  But in order to find it useful you must have
some linux command line knowlege, a lot of HTML/CSS knowlege (if you want to
modify the templates so your archive doesn't look like mine!), mysql knowlege,
maybe some perl knowledge, maybe some docker experience, and definitely an
understanding of file paths and basic sysadmin type stuff.

If it's not working for you, I apologize, but I don't have any time to help
you debug.  If it's _very_ important to you, and you're willing to pay a lot
of money (like a thousand US dollars or more), we may be able to work out
a temporary consulting gig.

# Installation Notes

## set up perl, install local::lib:

sudo apt install libmysqlclient-dev
sudo apt install libc6-dev
sudo apt install liblocal-lib-perl

perl -MCPAN -Mlocal::lib -e 'CPAN::install(Config::Fast)'
perl -MCPAN -Mlocal::lib -e 'CPAN::install(JSON)'
perl -MCPAN -Mlocal::lib -e 'CPAN::install(DBD::mysql)'
perl -MCPAN -Mlocal::lib -e 'CPAN::install(File::Slurp)'
perl -MCPAN -Mlocal::lib -e 'CPAN::install(Template::Toolkit)'

export PERL5LIB=/home/brian/sites/forums.massassi.net/src/lib

## Configure the database

In the `src/etc` directory, rename `config.conf-default` to `config.conf` and
modify the database settings to connect to your mysql database.

I strongly recommend you do all work on a copy of the database and connect
as a user that only has READONLY access.

## Start mysql (docker)

I have my database copy running under docker.  It was created like this:

```
docker run -it -v/home/brian/sites/forums.massassi.net/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d -p 3306:3306 --name mysql-forums --network mysql-network -e MYSQL_ROOT_PASSWORD=<REPLACEME> -e MYSQL_DATABASE=<REPLACEME> -d mysql:8.2.0
```

You'll have to adjust the volume mount paths (`-v` argument above).  By default,
when the mysql container runs, it will look inside the container at path
`/docker-entrypoint-initdb.d` for any `.sql` files, and will load them into
the database by default.  I dropped my database dump (which must include
attachments in the database if you want this to work!) in there as
`massfor_forums-2023-12-21-with-attachments.sql` (it can be named anything but
it must have a `.sql` extension).

Assuming the container has been started previously, and then turned off.

```
docker start mysql-forums
```

# HOW IT WORKS

Step 1: run `perl bin/export.pl`

This will query your database and dump a bunch of json into the `json_dir` you
configured in `config.conf`.  It will also dump all attachments to the
`attachments/` folder (TODO: need to make that configurable, I guess).

Step 2: run `perl bin/generate_html.pl`

This will process all the json files and generate a forums index, an index
page for each forum, an thread page for every thread.

My intention is also to automate writing apache or nginx redirect rules that
will help search engines recognize that the pages have moved permanently.
This is likely only useful if you're archiving and then taking down the old
forums.  I didn't want to try to preserve the URL structure on the filesystem
because as with everything vBulletin, it's nonsenical.  Example forum urls:

* https://forums.massassi.net/vb3/forumdisplay.php?8-Discussion-Forum
* https://forums.massassi.net/vb3/showthread.php?68318-Happy-New-Years!!

I mean... come on.



# various crap I don't think is useful anymore

decode the contenttype "class" field (w t f?)

select contenttypeid, class, convert(class, char) as class_label, packageid from contenttype order by contenttypeid;

code regarding importing attachments:
https://github.com/discourse/discourse/blob/main/script/import_scripts/vbulletin.rb#L608-L627

    attachments = mysql_query(<<-SQL)
      SELECT a.attachmentid, a.contentid as postid, p.threadid
        FROM #{TABLE_PREFIX}attachment a, #{TABLE_PREFIX}post p
       WHERE a.contentid = p.postid
       AND contenttypeid = 1 AND state = 'visible'
    SQL
