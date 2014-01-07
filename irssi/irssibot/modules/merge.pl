#!/usr/bin/perl -w
# CMDS merge

my $cmd = $$irc_event{cmd};
my $args = $$irc_event{args};

return reply("you lack permission.") if (not perms("admin", "meet", "merge"));

my ($irc_nick, $user) = split(/ /, $args);
if (($irc_nick eq "") or ($user eq "")) {
    reply("usage is !$cmd ircNick dbUser");
    return;
}

my $user_info = $$state{dbh}->selectrow_hashref("select * from ib_users WHERE ircnick = ?", undef, $user);
if (not exists $$user_info{ircnick}) {
    say("User '$user' was not found in the database.");
    return;
}

my $ircnick_host = "";
foreach my $channel (Irssi::channels()) {
    next if ($$channel{name} ne $$irc_event{target});
    foreach my $nick ($channel->nicks()) {
        next if ($nick->{nick} eq $channel->{ownnick}->{nick});
        if ($nick->{nick} =~ m#^$irc_nick$#i) {
            $ircnick_host = $nick->{host};
            last;
        }
    }
}

return say("Nick '$irc_nick' was not found in channel '$$irc_event{target}'.") if ($ircnick_host eq "");

my $tmp = $$state{dbh}->selectrow_hashref("select u.* from ib_users u, ib_hostmasks h WHERE u.id = h.users_id AND h.hostmask = ?", undef, $ircnick_host);
if (exists $$tmp{ircnick}) {
    say("Hostmask '$ircnick_host' for nick '$irc_nick' matches registered user '$$tmp{ircnick}'.");
    return;
}

$$state{dbh}->do("INSERT INTO ib_hostmasks (users_id, hostmask) VALUES (?, ?)", undef, $$user_info{id}, $ircnick_host);
say("Hostmask '$ircnick_host' added to '$user', '$irc_nick' is now identified.");
return;
