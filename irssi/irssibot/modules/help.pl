#!/usr/bin/perl -w
# CMDS help

my $cmd = $$irc_event{cmd};
my $args = $$irc_event{args};

if (($args ne "") and ($args !~ $$state{bot_commandre})) {
    say("Name '$args' is not a valid bot command.");
    say("Try !help with no arguments.");
    return;
}

if (exists $$state{modules}{$args}) {
    my $commands_text = join(", ", keys %{$$state{modules}{$args}{command}});
    say("Module '$args' commands:");
    say($commands_text);
    return;
}

my $modules_text = join(", ", keys %{$$state{modules}});
say("Installed modules:");
say($modules_text);
say("Try !help <module> for a commandlist for that module.");

