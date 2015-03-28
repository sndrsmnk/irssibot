#!/usr/bin/perl -w
# CMDS deluser 

my $cmd = $$irc_event{cmd};
my $args = $$irc_event{args};

my $deluser = $args;
return reply("function !deluser requires a nick as argument.") if ($deluser eq "");

return reply("you lack permission.") if (not perms("admin"));

my $user_info = $$state{dbh}->selectrow_hashref("select * from ib_users where ircnick = ?", undef, $deluser);
if (not exists $$user_info{ircnick}) {
    public("User '$deluser' does not exist.");
    return;
}

$$state{dbh}->do("DELETE FROM ib_hostmasks WHERE users_id = ?", undef, $$user_info{id});
$$state{dbh}->do("DELETE FROM ib_perms WHERE users_id = ?", undef, $$user_info{id});
$$state{dbh}->do("DELETE FROM ib_users WHERE id = ?", undef, $$user_info{id});

public("User '$deluser' was removed from the database.");
return;
