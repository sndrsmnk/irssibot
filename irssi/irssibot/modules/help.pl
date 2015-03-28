#!/usr/bin/perl -w
# CMDS help

my $cmd = $$irc_event{cmd};
my $args = $$irc_event{args};

if (($args ne "") and ($args !~ $$state{bot_commandre})) {
    public("Name '$args' is not a valid bot command.");
    public("Try !help with no arguments.");
    return;
}

if (exists $$state{modules}{$args}) {
    my $commands_text = join(", ", keys %{$$state{modules}{$args}{command}});
    public("Module '$args' commands:");
    public($commands_text);
    return;
}

my $modules_text = join(", ", keys %{$$state{modules}});
public("Installed modules:");
public($modules_text);
public("Try !help <module> for a commandlist for that module.");

