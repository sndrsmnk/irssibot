#!/usr/bin/perl -w
# CMDS tell

public("Test1.");
private("Test2.");

$$irc_event{server}->command("msg $$irc_event{nick} Test3.");
