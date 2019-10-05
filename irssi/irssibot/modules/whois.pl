#!/usr/bin/perl -w
# CMDS whois


return if not perms("user");
return if not exists $$irc_event{args} or $$irc_event{args} eq "";
return if $$irc_event{args} =~ m#(\d+\.\d+\.\d+\.\d+)#;


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
if ($$irc_event{target} eq lc($whois_nick) or lc($$irc_event{nick}) eq lc($whois_nick)) { # PRIVMSG handling, lowercase user input
    $whois_host = $$irc_event{address};
    $out .= "who i'm talking to as $whois_host. ";


} elsif ($whois_host eq "") {
    $out .= "not a party of this conversation. ";

} else {
    $out .= "on channel $$irc_event{target} as $whois_host. ";

}

public($out);
$out = "";

my $by_nick_user_info = $$state{dbh}->selectrow_hashref("SELECT * FROM ib_users WHERE ircnick = ?", undef, $whois_nick);
my $by_host_user_info = $$state{dbh}->selectrow_hashref("select u.* from ib_users u, ib_hostmasks h WHERE u.id = h.users_id AND h.hostmask = ?", undef, $whois_host);

my $recognized = $by_nick_user_info || $by_host_user_info || {};

return public("$whois_nick is currently unknown to me. Either by name or by hostmask. Introduce us?")
    if (not defined $$recognized{id});

public("Nick '$whois_nick' is recognized as registered user '" . $$recognized{ircnick} . "', status " . ($$by_host_user_info{id}?"ok":($$by_nick_user_info{id}?"needs-merge":"needs-meet")) . ".");

$out .= "Permissions: ";
my $users_id = $$recognized{id};
my $sth = $$state{dbh}->prepare("SELECT * FROM ib_perms WHERE users_id = ? AND (channel = ? OR channel = '' OR channel IS NULL) ORDER BY channel ASC");
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

public($out);
$out = "";

$out .= "Hostmasks: ";
my $sth = $$state{dbh}->prepare("SELECT * FROM ib_hostmasks WHERE users_id = ? ORDER BY hostmask ASC");
$sth->execute($users_id);
while (my $row = $sth->fetchrow_hashref()) {
    $out .= $$row{hostmask} . ", ";

}

$sth->finish();

$out =~ s/, $//;
public($out);
