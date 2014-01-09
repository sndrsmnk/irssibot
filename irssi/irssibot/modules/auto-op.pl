#!/usr/bin/perl -w
# CMDS message_join op

return if (not perms("auto-op"));

# if triggered by pubmsg, fix channel:
$$irc_event{channel} = $$irc_event{target} if not exists $$irc_event{channel};

my $i_am_op = 0;
foreach my $channel (Irssi::channels()) {
    next if ($$channel{name} ne $$irc_event{channel});
    foreach my $nick ($channel->nicks()) {
        if ($nick->{nick} eq $$irc_event{server}->{nick}) {
            $i_am_op = 1 if ($$nick{op} == 1);
        }
    }
}
return msg("I did not have op on $$irc_event{channel} to auto-op $$state{user_info}{ircnick}.") if not $i_am_op;

my $op_nick = $$irc_event{nick};
if (exists $$irc_event{cmd} and $$irc_event{cmd} eq "op") {
    if (exists $$irc_event{args} and $$irc_event{args} =~ m#^([^\s]+)#) {
        $op_nick = $1;
        msg("Op requested for $op_nick by $op_nick!$$irc_event{address} on $$irc_event{channel}");
    } else {
        msg("Op requested by $op_nick!$$irc_event{address} on $$irc_event{channel}");
    }
} else {
    msg("Auto-op $op_nick on $$irc_event{channel} (user $$state{user_info}{ircnick}).");
}

$$irc_event{server}->command("MODE $$irc_event{channel} +o $op_nick");
