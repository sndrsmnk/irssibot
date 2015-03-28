#!/usr/bin/perl -w
# CMDS save

return reply("you lack permission.") if (not perms("admin"));

save_configuration();

my @stat = stat($$state{bot_configfile});
public("Configuration is " . $stat[7] . " bytes, last modified " . localtime($stat[9]));
public("Done.");

my $temp = {};
foreach my $key (keys %$state) {
    # XXX not nice. use prefix?
    next if $key =~ m#^(?:act_channel|user_info|dbh|bot_is_op|modules)$#;
    $$temp{$key} = $$state{$key};
}

open (FD, ">$$state{bot_configfile}") or msg("Problems while writing configuration file: $!\n");
print FD Dumper($temp);
close(FD);
$temp = {}; undef $temp;


