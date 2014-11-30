#!/usr/bin/perl -w
# CMDS mac
#
# wget -O ~/.irssi/irssibot/oui.txt \
#     http://www.ieee.org/netstorage/standards/oui.txt
#
my ($cfgdir) = $$state{bot_configfile} =~ m#^(.*)/#;
my $oui_txt = $cfgdir . "/oui.txt";
my $oui_perl = $cfgdir . "/oui.txt.perlObj";


if ($$irc_event{args} =~ m#rebuild#) {
    return if (not perms('admin'));
    if (-e $oui_perl) {
        unlink $oui_perl;
        return reply("the OUI database was removed. Next lookup will (try to) rebuild it.");

    } else {
        return reply("no OUI database exists!");

    }
}


my $oui_db = {};
if (-e $oui_perl) {
    if (open(FD, "<".$oui_perl)) {
        local $/ = undef; my $blob = <FD>; close(FD);
        $oui_db = eval 'my ' . $blob;

    } else {
        return reply("there is a OUI datbase but i can't read it: $!");

    }
    
} elsif (-e $oui_txt) {
    if (open(FD, "<".$oui_txt)) {
        while (<FD>) {
            if (/\s+([-A-F0-9]{8})\s+.hex.\s+(.*)\s*/) {
                my ($oui, $desc) = ($1, $2);
                $oui = lc($oui);
                $oui =~ tr/a-f0-9//cd;
                $$oui_db{$oui} = $desc;
            }
        }

        if (open(FD, ">".$oui_perl)) {
            print FD Dumper($oui_db);
            close(FD);
            unlink($oui_txt);

        } else {
            reply("i couldn't write the OUI database to disk: $!");

        }

    } else {
        return reply("there is a oui.txt file but i can't read it: $!");

    }

} else {
    return reply("no oui.txt or OUI database was found :(");

}

my $mac = lc($$irc_event{args});
if ($mac !~ m#^[-a-f0-9:\.]{6,}$#) {
    return reply("'$mac' does not look like a MAC-address to me.");
}


$mac =~ tr/a-f0-9//cd;
$mac = substr($mac, 0, 6);


if (exists $$oui_db{$mac}) {
    return reply("$mac is " . $$oui_db{$mac});

} else {
    return reply("$mac is undefined");

}
