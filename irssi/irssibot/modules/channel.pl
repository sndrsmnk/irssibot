#!/usr/bin/perl -w
# CMDS channel-add channel-remove channel-del

return reply("you don't have the permissions to do this") if (not perms("channel"));

if ($$irc_event{cmd} =~ /^channel-add/) {
    return reply("what channel should I join?") if ($$irc_event{args} eq "");
    $$irc_event{server}->command("JOIN $$irc_event{args}");
    my ($channel, $args) = split / /, $$irc_event{args};
    Irssi::command("channel add -auto $channel $$irc_event{server}{tag} $args");
    Irssi::command("save");
    return;
}
if ($$irc_event{cmd} =~ /^channel-(remove|del)/) {
    return reply("what channel should I leave?") if ($$irc_event{args} eq "");
    $$irc_event{server}->command("PART $$irc_event{args}");
    Irssi::command("channel remove $$irc_event{args} $$irc_event{server}{tag}");
    Irssi::command("save");
    return;
}

return reply("unhandled channel event");
