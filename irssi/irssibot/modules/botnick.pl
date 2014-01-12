#!/usr/bin/perl -w
# CMDS botnick

return if (not perms("owner", "admin"));

return reply("... dude.") if ((not exists $$irc_event{args}) or ($$irc_event{args} eq ""));

$$irc_event{args} =~ m#^([\{\}\[\]a-z0-9_-]+)#;
my $bot_nick = $1;

msg("Nick change requested by $$irc_event{nick} on $$irc_event{channel}: $bot_nick");
$$irc_event{server}->command("NICK $bot_nick");
