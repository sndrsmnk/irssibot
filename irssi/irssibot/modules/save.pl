#!/usr/bin/perl -w
#
# Commands (!command) this module triggers must follow '# CMDS ':
# CMDS save
#^^^^^^
#

save_configuration();

my @stat = stat($$state{bot_configfile});
say("Configuration is " . $stat[7] . " bytes, last modified " . localtime($stat[9]));
say("Done.");
