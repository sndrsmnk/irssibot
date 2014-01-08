#!/usr/bin/perl -w
# CMDS message_join

#qw(server channel nick address))

# XXX FIXME dit moet op basis van $$irc_event{channel}
return if (not perms("auto-op"));

my $i_am_op = 0;
foreach my $channel (Irssi::channels()) {
    next if ($$channel{name} ne $$irc_event{channel});
    foreach my $nick ($channel->nicks()) {
        if ($nick->{nick} eq $$irc_event{server}->{nick}) {
            $i_am_op = 1 if ($$nick{op} == 1);
        }
    }
}

return msg("I did not have op on $$irc_event{channel} when $$state{user_info}{ircnick} joined who has auto-op perms.") if not $i_am_op;

$$irc_event{server}->command("MODE $$irc_event{channel} +o $$irc_event{nick}");
msg("Auto-op $$irc_event{nick} on $$irc_event{channel} (user $$state{user_info}{ircnick}).");
