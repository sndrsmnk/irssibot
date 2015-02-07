irssibot
====
This is an IRC bot implementation built with irssi Perl scripting.<br/>
(c) 2014, 2015 GPLv2+ - There may be dragons.

You may need some or all of these Ubuntu packages: irssi, mysql-server, libdbi-perl, libwww-perl, liburi-escape-perl, libhtml-html5-entities-perl, libxml-xpath-perl

Quick install guide:
----
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
   * I would advise not to run other plugins with this bot, they may clash.
   * You might want to disable irssi's flood protection features if you plan to use the UDP listener a lot:
     * ```/set cmds_max_at_once 0```
     * ```/set cmd_queue_speed 0msec```
 * Join IRC, claim the bot, use !help, **read the source** and remember that i didn't write this for you, i wrote this for me. ;)

UDP listener
----
To configure the UDP-listener, you may need to set some configuration options after the bot was claimed. A module named 'set' can be used by the owner to set (almost) any value in the bot's state hash:

```text
!set udp_listen_ip ::ffff:127.0.0.1
!set udp_listen_port 47774
!set udp_listen_pass s00p3rzeeKRiT!
```

**NOTE**: The ```udp_listen_ip``` **must** be specified in IP6 notation. Prepend ```::ffff:``` to IPv4 addresses if used.

After changing these values, use the ```!udp-reopen``` command to re-open ('restart') the UDP-listener.<br/>
Use the ```!save``` command to make the configuration permanent.

You can now send UDP-datagrams to the IP and port specified to have the bot output them on IRC:
```sh
$ echo "s00p3rzeeKRiT! #testchan Test message via UDP" | nc -q1 -u 127.0.0.1 47774
```
If the bot is on multiple networks with the same channelname, you can specify the irssi network name to help the bot decide where to output the message:
```sh
$ echo "s00p3rzeeKRiT! ircnet #testchan Test message on ircnet via UDP" | nc -q1 -u 127.0.0.1 47774
```
