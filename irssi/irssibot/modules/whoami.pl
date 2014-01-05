#!/usr/bin/perl -w
#
# Run for the following commands:
# CMDS whoami
# ^^^^ 
#

my $irc_event = \%_;
my $log_txt = "you are $$irc_event{nick}!$$irc_event{address} at $$irc_event{target}";
if (exists $$state{user_info}{ircnick}) {
    $log_txt .= ", registered user " . $$state{user_info}{ircnick} . " with perms: " . join(", ", @{$$state{user_info}{permissions}});
} else {                                                                           
    $log_txt .= ", unrecognised user.";
}
$log_txt .= ". And you are my owner." if (match($$state{bot_ownermask}));
return reply($log_txt);
