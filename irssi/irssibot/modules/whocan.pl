#!/usr/bin/perl -w
# CMDS whocan


return if not exists $$irc_event{args} or $$irc_event{args} eq "";
return if not perms("user");


my $whocan_perm = $$irc_event{args};


my $nicks = $$state{dbh}->selectcol_arrayref(
    "SELECT DISTINCT(iu.ircnick)
        FROM ib_users iu
        LEFT JOIN ib_perms ip
        ON iu.id = ip.users_id
        WHERE
            (ip.permission = ? OR ip.permission = 'admin')
            AND (ip.channel = ? OR ip.channel = '')",
    undef,
    $whocan_perm, $$irc_event{channel}
);

return reply("no-one can do that on " . $$irc_event{channel})
    if (not scalar(@{$nicks}));

my $out = "The following nicks can '".$whocan_perm."' on " . $$irc_event{channel} . ": ";
$out .= join ", ", @{$nicks};
    
say($out);
