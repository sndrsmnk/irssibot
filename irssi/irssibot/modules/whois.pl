#!/usr/bin/perl -w
# CMDS whois

return if not exists $$irc_event{args} or $$irc_event{args} eq "";
return if not perms("user");


my $whois_nick = $$irc_event{args};
my $whois_host = "";


foreach my $channel (Irssi::channels()) {
    next if ($$channel{name} ne $$irc_event{target});
    foreach my $nick ($channel->nicks()) {
        if ($nick->{nick} =~ m#^$whois_nick$#i) {
            $whois_host = $nick->{host};
            last;
        }
    }
}


my $out = "$whois_nick is ";
if ($whois_host eq "") {
    $out .= "not on channel $$irc_event{target}. ";
} else {
    $out .= "on channel $$irc_event{target} as $whois_host. ";
}


my $recognized = 0;
my $user_info;
if ($whois_host) {
    $user_info = $$state{dbh}->selectrow_hashref("select u.* from ib_users u, ib_hostmasks h WHERE u.id = h.users_id AND h.hostmask = ?", undef, $whois_host);
    if (exists $$user_info{ircnick}) {
        $out .= "$whois_nick is recognised as $$user_info{ircnick}. ";
        $recognized++;
    } else {
        $out .= "$whois_nick is not recognised as a registered user. ";
    }
}


if (not $recognized) {
    $user_info = $$state{dbh}->selectrow_hashref("SELECT * FROM ib_users WHERE ircnick = ?", undef, $whois_nick);
    if (exists $$user_info{ircnick}) {
        $out .= "A registered user named $whois_nick was found. ";
    } else {
        return say($out . "No registered user named $whois_nick was found either.");
    }
}


$out .= "Permissions: ";


my $users_id = $$user_info{id};
my $sth = $$state{dbh}->prepare("SELECT * FROM ib_perms WHERE users_id = ? AND (channel = ? OR channel = '') ORDER BY channel ASC");
$sth->execute($users_id, $$irc_event{channel});
while (my $row = $sth->fetchrow_hashref()) {
    $out .= $$row{permission};
    if ($$row{channel} ne "") {
        $out .= "($$row{channel}) ";
    } else {
        $out .= "(global) ";
    }
}
$sth->finish();


say($out);
