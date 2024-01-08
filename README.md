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

## path notes

Any time you see a filesystem path in this README, you should change it to a
path that makes sense on your system.  These are all paths on my system,
and yours won't match.  Unless you're also named `brian` maybe.

## set up perl, install local::lib

Some perl dependencies installed using apt on Linux Mint / Ubuntu.  If you're
using another distro, you could just try to add them using local::lib as below,
or find matching packages in your package repo.

```
sudo apt install libmysqlclient-dev
sudo apt install libc6-dev
sudo apt install liblocal-lib-perl
```

Some perl dependencies that get installed from CPAN into your local::lib.  On
my system these modules go into `~/perl5/` (in my home directory) so they
don't interfere with the system perl at all (and no need to run as root/sudo to
install them either).

```
perl -MCPAN -Mlocal::lib -e 'CPAN::install(Config::Fast)'
perl -MCPAN -Mlocal::lib -e 'CPAN::install(JSON)'
perl -MCPAN -Mlocal::lib -e 'CPAN::install(DBD::mysql)'
perl -MCPAN -Mlocal::lib -e 'CPAN::install(File::Slurp)'
perl -MCPAN -Mlocal::lib -e 'CPAN::install(Template::Toolkit)'
perl -MCPAN -Mlocal::lib -e 'CPAN::install(Parse::BBCode)'
```

For any perl command to work you need to tell it where to find the modules
I wrote.  Easiest way to use PERL5LIB environment variable.  You can type
this in each shell before you use any of the perl commands.  You could also
add this to `bin/activate` and then `source bin/activate` on each new shell.
You could also add it to your `.bashrc` but then the change would be global.

```
export PERL5LIB=/home/brian/sites/forums.massassi.net/src/lib
```

## Configure the database

In the `etc/` directory, rename `config.conf-default` to `config.conf` and
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

# STUPID ANNOYING NOTES

I couldn't figure out how to make Parse::BBCode stop escaping `&amp;`
ampersands.  Vbulletin stores entities like `&#64;` inside their tables.  The
Parse::BBCode module translates it into `&amp;#64;` which is nonsensical and
doesn't render.  So I went into their code and commented out the section that
does that.  Must research further, there has to be a better way.

# LICENSE

TODO
