#!/usr/bin/perl -w
# CMDS perm 

return reply("you lack permission.") if (not perms("admin", "perm"));

my $cmd = $$irc_event{cmd};
my $args = $$irc_event{args};
$args =~ s/\s{2,}/ /g;

my @perms = split / /, $args;
if (scalar(@perms) < 3) {
    reply("usage is !$cmd <add|remove> <nick> <permission1> [..<permissionN>] [<channel>]");
    return;
}
my $mode = shift @perms;
my $nick = shift @perms;

my $channel = "";
$channel = pop @perms if (isChannel($perms[$#perms]));

my $user_info = $$state{dbh}->selectrow_hashref("SELECT * FROM ib_users WHERE ircnick = ?", undef, $nick);
if (not exists $$user_info{ircnick}) {
    public("User '$nick' does not exist.");
    return;
}

if ($mode =~ m#(?:set|add)#) {
    my $count = 0;
    foreach my $permission (@perms) {
        $$state{dbh}->do("INSERT INTO ib_perms (users_id, permission, channel) VALUES (?, ?, ?)", undef, $$user_info{id}, $permission, $channel);
        $count++;
        if ($DBI::errstr ne "") {
            public("Database failure while inserting permission '$permission'");
            $count--;
        }
    }
    public("Added $count permission(s) to $nick");
}


if ($mode =~ m#(?:rem(?:ove)?|del(?:ete)?)#) {
    my $count = 0;
    foreach my $permission (@perms) {
        $$state{dbh}->do("DELETE FROM ib_perms WHERE users_id = ? AND permission = ? AND channel = ?", undef, $$user_info{id}, $permission, $channel);
        $count++;
        if ($DBI::errstr ne "") {
            public("Database failure while removing permission '$permission'");
            $count--;
        }
    }
    public("Removed $count permission(s) from $nick");
}

return;
