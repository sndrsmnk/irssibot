#!/usr/bin/perl -w
# CMDS bd-set oud age

return if not perms("user");

my @monts = ('jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec');
my $cmd = $$irc_event{cmd};
my $args = $$irc_event{args};


if ($cmd =~ m#(?:oud|age)#) {
    my $lookup_nick = $$state{user_info}{ircnick};
    my $prefix = "You are";
    if ($args) {
        $lookup_nick = $args;
        $prefix = "$lookup_nick is";
    }

    my ($agedays) = @{$$state{dbh}->selectcol_arrayref("SELECT DATEDIFF(NOW(), dob) FROM ib_users WHERE ircnick = ?", undef, $lookup_nick)};
    return reply("No DOB information for $lookup_nick") if not $agedays;
    my $ageyears = sprintf("%0.3f", ($agedays / 365)); #ish.

    public("$prefix approximately $agedays days ($ageyears years) old.");
}


if ($cmd eq 'bd-set') {
    my $dob = ""; my $d = my $m = my $y = 0;
    if ($args =~ m#^(\d{1,2})-(\d{1,2})-(\d{4})#) {
        $dob = sprintf("%04d-%02d-%02d", $3, $2, $1);
    } elsif ($args =~ m#^(\d{4})-(\d{1,2})-(\d{1,2})#) {
        $dob = sprintf("%04d-%02d-%02d", $1, $2, $3);
    }
    if ($dob eq "") {
        public("Failed to parse date from '$args', expecting yyyy-mm-dd or dd-mm-yyyy.");
        return;
    }

    $$state{dbh}->do("UPDATE ib_users SET dob = ? WHERE id = ?", undef, $dob, $$state{user_info}{id});
    my $dbd = $$state{dbh}->selectcol_arrayref("SELECT dob FROM ib_users WHERE id = ?", undef, $$state{user_info}{id});
    if ($$dbd[0] eq "0000-00-00") {
        public("'$dob' is not a correct date, expecting yyyy-mm-dd or dd-mm-yyyy.");
        return;
    }

    my $agedays = @{$$state{dbh}->selectcol_arrayref("SELECT DATEDIFF(NOW(), dob) FROM ib_users WHERE id = ?", undef, $$state{user_info}{id})}[0];
    my $ageyears = sprintf("%0.3f", ($agedays / 365)); #ish.

    public("Stored! You are approximately $agedays days ($ageyears years) old.");
}


sub showduration {
    my ($seconds) = @_;
    my $orig = $seconds;
    my $years = int($seconds / 31536000);
    $seconds -= ($years * 31536000);
    my $months = int($seconds / 2635200);
    $seconds -= ($months * 2635200);
    my $days = int($seconds / 86400);
    $seconds -= ($days * 86400);
    return sprintf("%03dy%02dm%02dd", $years, $months, $days);
}


# 
# my $nicks = $$state{dbh}->selectcol_arrayref(
#     "SELECT DISTINCT(iu.ircnick)
#         FROM ib_users iu
#         LEFT JOIN ib_perms ip
#         ON iu.id = ip.users_id
#         WHERE
#             (ip.permission = ? OR ip.permission = 'admin')
#             AND (ip.channel = ? OR ip.channel = '')",
#     undef,
#     $whocan_perm, $$irc_event{channel}
# );
# 
# return reply("no-one can do that on " . $$irc_event{channel})
#     if (not scalar(@{$nicks}));
# 
# my $out = "The following nicks can '".$whocan_perm."' on " . $$irc_event{channel} . ": ";
# $out .= join ", ", @{$nicks};
#     
# public($out);
