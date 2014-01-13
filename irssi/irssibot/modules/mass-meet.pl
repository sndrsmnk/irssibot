#!/usr/bin/perl -w
# CMDS mass-meet

my $cmd = $$irc_event{cmd};
my $args = $$irc_event{args};

return reply("you lack permission.") if (not perms("admin"));

foreach my $channel (Irssi::channels()) {
    next if ($$channel{name} ne $$irc_event{target});
    foreach my $nick ($channel->nicks()) {
        next if ($nick->{nick} eq $channel->{ownnick}->{nick});

        my $tmp_user_info = $$state{dbh}->selectrow_hashref("SELECT u.* FROM ib_users u, ib_hostmasks h WHERE u.id = h.users_id AND h.hostmask = ?", undef, $nick->{host});
        if (exists $$tmp_user_info{ircnick}) {
            say ("Already recognised as $$tmp_user_info{ircnick}: $nick->{nick}");
            next;
        }

        $tmp_user_info = $$state{dbh}->selectrow_hashref("SELECT * FROM ib_users WHERE ircnick = ?", undef, $nick->{nick});
        if (exists $$tmp_user_info{ircnick}) {
            say("Merged '".$nick->{address}."' to user $$tmp_user_info{ircnick}");
            $$state{dbh}->do("INSERT INTO ib_hostmasks (users_id, hostmask) VALUES (?, ?)", undef, $$tmp_user_info{id}, $nick->{host});
            next;
        }

        $$state{dbh}->do("INSERT INTO ib_users (ircnick, insert_time) VALUES (?, NOW())", undef, $nick->{nick});
        ($tmp_user_info) = $$state{dbh}->selectrow_array("SELECT id FROM ib_users WHERE ircnick = ?", undef, $nick->{nick});
        msg("New user with users_id '$tmp_user_info', '$nick->{nick}', '$nick->{host}'");
        $$state{dbh}->do("INSERT INTO ib_hostmasks (users_id, hostmask) VALUES (?, ?)", undef, $tmp_user_info, $nick->{host});
        $$state{dbh}->do("INSERT INTO ib_perms (users_id, permission) VALUES (?, 'user')", undef, $tmp_user_info);

        say("Added to database '$nick->{nick}' at '$nick->{host}'.");
    }

}

say("Done!");
return;
