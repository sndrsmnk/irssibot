#!/usr/bin/perl -w
# CMDS dumper

return reply("you lack permission.") if (not perms("owner"));

msg("\$irc_event_");
msg(Dumper(\$irc_event));

msg("");

msg("\$state:");
msg(Dumper($state));

public("Done.");
