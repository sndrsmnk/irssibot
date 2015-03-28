#!/usr/bin/perl -w
# CMDS set unset

## Only admins can use this module.
return reply("you lack permission.") if (not perms("admin"));

## This directly changes the irssibot $state hashref.
## Be careful. ;)

my $key = my $value = undef;

if ($$irc_event{cmd} eq 'set') {
    ($key, $value) = $$irc_event{args} =~ m#^(\S+)\s(.*)#;
    $$state{$key} = $value;
    save_configuration();
    return public("State key '$key' set to value '$value'.");

} elsif ($$irc_event{cmd} eq 'unset') {
    delete $$state{$$irc_event{args}};
    save_configuration();
    return public("State key '".$$irc_event{args}."' removed.");
}

return reply("Uncaught set module event :(");
