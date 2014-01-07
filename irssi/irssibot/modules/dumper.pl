#!/usr/bin/perl -w
# CMDS dumper

return reply("you lack permission.") if (not perms("owner"));

msg("\%_");
msg(Dumper(\%_));

msg("");

msg("\$state:");
msg(Dumper($state));

say("Done.");
