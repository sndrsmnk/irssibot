#!/usr/bin/perl -w
# CMDS udp-reopen

## Only admins can use this module.
return reply("you lack permission.") if (not perms("admin"));

if ($$irc_event{cmd} =~ /^udp-reopen/) {
    openUDPSocket();
    return reply("UDP listener reopened.");
}


return reply("Uncaught UDP module event :(");
