#!/usr/bin/perl -w
# CMDS message_public

return if (not perms("user"));

my $msg = $$irc_event{msg};
return if $msg !~ $$state{bot_triggerre};

$msg =~ s#$$state{bot_triggerre}##;

if ($msg =~ /^(.+?) = (.+?)$/) { # request to set a value
    my $key = $1; my $value = $2;
    my $db_key = $key; lc($db_key);

    my $rv = $$state{dbh}->do("INSERT INTO ib_infoitems (users_id, item, value, channel) VALUES (?, ?, ?, ?)", undef, $$state{user_info}{id}, $key, $value, $$irc_event{channel});
    if (defined $rv and $rv != 0) {
        return reply("item added.");
    } else {
        if ($DBI::errstr =~ m#Duplicate entry#i) {
            return reply("value '$value' is a duplicate entry.");
        }
        return reply("something with the database failed.");
    }

} elsif ($msg =~ /^forget (.*) ([-_\.:a-zA-Z0-9]+)$/) {
    my $key = $1; my $match = $2;
    return reply("you lack permission.") if (not perms("forget", "admin"));

    my $rv = $$state{dbh}->do("DELETE FROM ib_infoitems WHERE channel = ? AND item = ? AND value LIKE ?", undef, $$irc_event{channel}, $key, '%'.$match.'%');
    if ($rv eq "0E0") {
        reply("no items matched '$match'.");
    } else {
        reply("$rv item(s) removed.");
    }
        
} elsif ($msg =~ /^(.+?)\?$/) {	# request for explanation
    my $key = $1;
    my @values = @{$$state{dbh}->selectcol_arrayref("SELECT value FROM ib_infoitems WHERE item = ? AND channel = ? ORDER BY insert_time ASC", undef, $key, $$irc_event{channel})};
    if (not scalar(@values)) {
        reply("no definitions for that item.");
    } else {
        public("$key is: " . join(" .. ", @values));
    }
}
