#!/usr/bin/perl -w
# CMDS mass-perm

return reply("you lack permission.") if (not perms("admin", "mass-perm"));

my $cmd = $$irc_event{cmd};
my $args = $$irc_event{args};
$args =~ s/\s{2,}/ /g;

my @perms = split / /, $args;
if (scalar(@perms) < 2) {
    reply("usage is !$cmd <add|remove> <permission1> [..<permissionN>] (mass-perms are channel specific)");
    return;
}
my $mode = shift @perms;


my $log_counters = {};
foreach my $channel (Irssi::channels()) {
    next if ($$channel{name} ne $$irc_event{target});
    foreach my $nick ($channel->nicks()) {
        next if ($nick->{nick} eq $channel->{ownnick}->{nick});

        my $tmp_user_info = $$state{dbh}->selectrow_hashref("SELECT u.* FROM ib_users u, ib_hostmasks h WHERE u.id = h.users_id AND h.hostmask = ?", undef, $nick->{host});
        if (exists $$tmp_user_info{ircnick}) {
            foreach my $perm (@perms) {
                $$state{dbh}->do("INSERT IGNORE INTO ib_perms (users_id, permission, channel) VALUES (?, ?, ?)", undef, $$tmp_user_info{id}, $perm, $$irc_event{channel});
            }
        }
    }
}

public("Done. Or at least i tried.");

