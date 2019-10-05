#!/usr/bin/perl -w
# CMDS whoami test

my $log_txt = "you are $$irc_event{nick}!$$irc_event{address} at $$irc_event{target}";
if (exists $$state{user_info}{ircnick}) {
    $log_txt .= ", registered user " . $$state{user_info}{ircnick};

    if (exists $$state{user_info}{permissions}{global}) {
        $log_txt .= ", with global perms (" . join(", ", keys %{$$state{user_info}{permissions}{global}}) . ")";
    }
    if (exists $$state{user_info}{permissions}{$$irc_event{target}}) {
        $log_txt .= ", with $$irc_event{target} perms (" . join(", ", keys %{$$state{user_info}{permissions}{$$irc_event{target}}}) . ")";
    }
} else {                                                                           
    $log_txt .= ", unrecognised user";
    my $by_nick_user_info = $$state{dbh}->selectrow_hashref("SELECT * FROM ib_users WHERE ircnick = ?", undef, $$irc_event{nick});
    if ($$by_nick_user_info{id}) {
        $log_txt .= ", but a user was found in the DB, perhaps you need a merge?";
    }
}
$log_txt .= " - and you are my owner!" if (match($$state{bot_ownermask}));
return reply($log_txt);
