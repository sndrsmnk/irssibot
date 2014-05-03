irssibot
========

This is an IRC bot implementation built with irssi Perl scripting.

(c) GPLv2+ for the daring, but:

Insert disclaimers here.
------------------------------------------------
No. Really. There may be dragons.

You may need Ubuntu packages: irssi, mysql-server, libdbi-perl, libwww-perl.

Install basic gist:

 * Create a new user '**irssibot**' (or joe, polly or finnigan...)

 * Checkout this repo in $HOME
```sh
$ git clone https://github.com/sndrsmnk/irssibot.git
$ mv -n .irssi OLD.irssi
$ ln -sf $HOME/irssibot/irssi $HOME/.irssi
```

 * Set up a proper **.my.cnf** file to connect to MySQL:
```mysql
 $ cat $HOME/.my.cnf
 [client]
 user=irssibot
 password=s00p3rzeeKRiT!
 host=foo.example
 database=irssibot
```

 * Create the database, grant the rights, etc.
 use **$HOME/.irssi/irssibot/mysql/dbschema.mysql** as schema

 * Start irssi, read the script output in irssi status window as it shows the '**unique id**' of the bot and how to claim ownership.

 * Set up irssi as you would normally do, configure networks, servers, channels, specify auto{connect,join} etc.

 * Join IRC, claim the bot, use !help, **read the source** and remember that i didn't write this for you, i wrote this for me. ;)
