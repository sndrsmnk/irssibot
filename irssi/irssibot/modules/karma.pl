#!/usr/bin/perl -w
# CMDS message_public
# CMDS karma
# CMDS who-karma-up who-up
# CMDS who-karma-down who-down
# CMDS why-karma-up why-up
# CMDS why-karma-down why-down
# CMDS goodness badness
# CMDS fans haters

return if (not perms("user"));

my $msg = $$irc_event{msg};
return if $msg !~ $$state{bot_triggerre};
$msg =~ s#$$state{bot_triggerre}##;


# this case is handled by quotes.pl
return if $msg =~ m#^quote\s*\d+\s*(?:\+\+|\-\-)#;


if ($$irc_event{trigger} eq "module_command") {
    if ($msg =~ /^(?:why-karma-(up|down)|why-(up|down))\s*(.*)/) {
        my $direction = $1 || $2;
        my $item = $3;
        $direction = "up" if $direction =~ m#^u#i;
        $direction = "down" if $direction =~ m#^d#i;
        return if (not defined $item or $item eq "");

        my $karma_item = $$state{dbh}->selectrow_hashref("
            SELECT * FROM ib_karma WHERE item = ? AND channel = ?",
            undef,
            $item, $$irc_event{channel}
        );

        my @reasons = @{$$state{dbh}->selectcol_arrayref("
            SELECT reason FROM ib_karma_why WHERE
                karma_id = ? AND direction = ? AND channel = ?
            ORDER BY update_time DESC
            LIMIT 10",
            undef,
            $$karma_item{id}, $direction, $$irc_event{channel}
        )};

        my $c = scalar(@reasons);
        if ($c) {
            return reply("$c most recent reason(s): " . join(" .. ", @reasons));
        } else {
            return reply("no reasons were given for karma $direction on '$item'");
        }


    } elsif ($msg =~ /^(?:who-karma-(up|down)|who-(up|down))\s*(.*)/) {
        my $direction = $1 || $2;
        my $item = $3;
        $direction = "up" if $direction =~ m#^u#i;
        $direction = "down" if $direction =~ m#^d#i;
        return if (not defined $item or $item eq "");

        my $karma_item = $$state{dbh}->selectrow_hashref("
            SELECT * FROM ib_karma WHERE item = ? AND channel = ?",
            undef,
            $item, $$irc_event{channel}
        );
        
        my $ret = undef;
        my $sth = $$state{dbh}->prepare(
           "SELECT u.ircnick, kwho.amount, k.item
            FROM ib_users u, ib_karma_who kwho, ib_karma k
            WHERE
                u.id = kwho.users_id
            AND kwho.karma_id = ?
            AND k.id = ?");
        $sth->execute($$karma_item{id}, $$karma_item{id});
        while (my $row = $sth->fetchrow_hashref()) {
            $ret = defined $ret ? $ret . " .. $$row{item}($$row{karma})" : "$$row{item}($$row{karma})";
        }
        reply($ret);

    } elsif ($msg =~ /^(fans|haters)\s*(.*)$/) {
        my $orig_direction = $1;
        my $direction = $orig_direction;
        my $item = $2;

        $direction = "up" if $direction eq "fans";
        $direction = "down" if $direction eq "haters";
        $orig_direction = ucfirst(lc($orig_direction));
 
        my $karma_item = $$state{dbh}->selectrow_hashref("
            SELECT * FROM ib_karma WHERE item = ? AND channel = ?",
            undef,
            $item, $$irc_event{channel}
        );
        return say("No such karma item, '$item'.") if not defined $$karma_item{item};

        my $sth = $$state{dbh}->prepare(
            "SELECT kw.id AS ib_karma_who_id,
                    kw.amount AS amount,
                    u.id AS ib_users_id,
                    u.*
            FROM ib_karma_who kw, ib_users u
            WHERE u.id = kw.users_id
                AND karma_id = ?
                AND direction = ?
            ORDER BY amount DESC LIMIT 10"
        );
        $sth->execute($$karma_item{id}, $direction);

        my $ret = undef;
        while (my $row = $sth->fetchrow_hashref()) {
            $ret = defined $ret ? $ret . " .. $$row{ircnick}($$row{amount})" : "$$row{ircnick}($$row{amount})";
        }

        if (defined $ret) {
            return say("$orig_direction of '$$karma_item{item}' are $ret");
        } else {
            return say("No " . lc($orig_direction) . " for '$$karma_item{item}' are known.");
        }


    } elsif ($msg =~ /^(good|bad)ness\s*$/) {
        my $direction = $1;
        my $sql_direction = "";
        $sql_direction = "ASC" if $direction eq "bad";
        $sql_direction = "DESC" if $direction eq "good";
 
        my $ret = undef;
        my $sth = $$state{dbh}->prepare("SELECT item, karma FROM ib_karma WHERE channel = ? ORDER BY karma $sql_direction LIMIT 10");
        $sth->execute($$irc_event{channel});
        while (my $row = $sth->fetchrow_hashref()) {
            $ret = defined $ret ? $ret . " .. $$row{item}($$row{karma})" : "$$row{item}($$row{karma})";
        }
        return reply("karma ${direction}ness: " . $ret);


    } elsif ($msg =~ /^karma\s*(.*)/) {
        my $item = $1;
        return if ((not defined $item) or ($item eq ""));
        my $karma_item = $$state{dbh}->selectrow_hashref("
            SELECT * FROM ib_karma WHERE item = ? AND channel = ?",
             undef,
            $item, $$irc_event{channel}
        );
        if (defined $$karma_item{karma}) {
            return reply("karma for '$item' is $$karma_item{karma}.");
        }
        return reply("karma for '$item' is neutral.");
    }


} elsif ($msg =~ /^(.+?)([\+\-]{2})(?:\s*#\s*(.*))?/) {
    my $item = $1;
    my $direction = $2;
    my $reason = $3;

    my $update_sql = "";
    if ($direction eq "++") {
        $direction = "up";
        $update_sql = "karma = karma + 1";
    } elsif ($direction eq "--") {
        $direction = "down";
        $update_sql = "karma = karma - 1";
    }

    my $rv = $$state{dbh}->do("
        INSERT INTO ib_karma (item, karma, channel)
        VALUES (?, 1, ?)
        ON DUPLICATE KEY
            UPDATE $update_sql",
        undef,
        $item, $$irc_event{channel}
    );

    my $karma_item = $$state{dbh}->selectrow_hashref("
        SELECT * FROM ib_karma WHERE item = ? AND channel = ?",
        undef,
        $item, $$irc_event{channel}
    );

    $$state{dbh}->do("
        INSERT INTO ib_karma_who (karma_id, users_id, direction, amount)
        VALUES (?, ?, ?, 1)
        ON DUPLICATE KEY
            UPDATE amount = amount + 1",
        undef,
        $$karma_item{id},
        $$state{user_info}{id},
        $direction);

    if (defined $reason and $reason ne "") {
        my $rv = $$state{dbh}->do("
            INSERT INTO ib_karma_why (karma_id, direction, reason, channel)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY
                UPDATE update_time = NOW()",
            undef,
            $$karma_item{id}, $direction, $reason, $$irc_event{channel}
        );
        reply("karma for '$item' is now $$karma_item{karma} - '$reason'");
    } else {
        reply("karma for '$item' is now $$karma_item{karma}");
    }


}
