#!/usr/bin/perl -w
#
# Run for the following commands:
# CMDS perm 
# ^^^^ 
#

return reply("you lack permission.") if (not perms("admin", "perm"));

my $irc_event = \%_;
my $cmd = $$irc_event{cmd};
my $args = $$irc_event{args};
$args =~ s/\s{2,}/ /g;

my @perms = split / /, $args;
if (scalar(@perms) < 3) {
    reply("usage is !$cmd <add|remove> <nick> <permission>");
    return;
}
my $mode = shift @perms;
my $nick = shift @perms;

my $user_info = $$state{dbh}->selectrow_hashref("SELECT * FROM ib_users WHERE ircnick = ?", undef, $nick);
if (not exists $$user_info{ircnick}) {
    say("User '$nick' does not exist.");
    return;
}

if ($mode eq "add") {
    my $count = 0;
    foreach my $permission (@perms) {
        $$state{dbh}->do("INSERT INTO ib_perms (users_id, permission) VALUES (?, ?)", undef, $$user_info{id}, $permission);
        $count++;
        if ($DBI::errstr ne "") {
            say("Database failure while inserting permission '$permission'");
            $count--;
        }
    }
    say("Added $count permission(s) to $nick");
}


if ($mode eq "remove") {
    my $count = 0;
    foreach my $permission (@perms) {
        $$state{dbh}->do("DELETE FROM ib_perms WHERE users_id = ? AND permission = ?", undef, $$user_info{id}, $permission);
        $count++;
        if ($DBI::errstr ne "") {
            say("Database failure while removing permission '$permission'");
            $count--;
        }
    }
    say("Removed $count permission(s) from $nick");
}

return;
