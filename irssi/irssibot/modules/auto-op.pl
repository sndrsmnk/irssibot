#!/usr/bin/perl -w
# CMDS message_join op voice

return if (not perms("auto-op") and not perms("auto-voice"));
return if not botIsOp($$irc_event{channel});

my $nick = $$irc_event{nick};
my $op_nick = $nick;
my $mode = "";

if (exists $$irc_event{cmd} and $$irc_event{cmd} =~ m#(op|voice)#) {
    $mode = $1;
    if (exists $$irc_event{args} and $$irc_event{args} =~ m#^([^\s]+)#) {
        $op_nick = $1;
        msg("$mode requested for $op_nick by $nick!$$irc_event{address} on $$irc_event{channel}");
    } else {
        msg("$mode requested by $nick!$$irc_event{address} on $$irc_event{channel}");
    }
} else {
    msg("Auto-op / Auto-voice $op_nick!$$irc_event{address} on $$irc_event{channel} (user $$state{user_info}{ircnick}).");
}

# XXX this will voice owner always, too. perms() seems to return 1 always if owner ;)
$$irc_event{server}->command("MODE $$irc_event{channel} +o $op_nick") if (perms("auto-op") or $mode eq "op");
$$irc_event{server}->command("MODE $$irc_event{channel} +v $op_nick") if (perms("auto-voice") or $mode eq "voice");
