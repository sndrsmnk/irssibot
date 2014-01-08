#!/usr/bin/perl -w
# CMDS owner

my $bot_ownermask = $$irc_event{nick} . '!' . $$irc_event{address};

if ((defined $$state{bot_ownermask}) and (not match($$state{bot_ownermask}))) {
    reply("no you're not.");
    return;
} elsif ((defined $$state{bot_ownermask}) and (match($$state{bot_ownermask}))) {
    reply("yes, you are.");
    return;
}

my $args = $$irc_event{args};
if ($args eq "") {
    reply("usage is !owner <uniqueid>");
    return;
}

if ($args ne $$state{bot_uniqueid}) {
    reply("'$args' is not my Unique ID.");
    msg("My Unique ID is ".$$state{bot_uniqueid});
    return;
}

$$state{bot_ownermask} = $bot_ownermask;
$$state{bot_uniqueid} = join("", (0..9, 'A'..'Z', 'a'..'z')[rand 62, rand 62, rand 62, rand 62, rand 62, rand 62, rand 62, rand 62]);

msg("Bot was claimed by " . $$state{bot_ownermask});
msg("My Unique ID changed to " . $$state{bot_uniqueid});

save_configuration();
load_configuration();
initialize();
save_configuration();

say("My master, $bot_ownermask. Thanks. Things have been set-up and loaded.");
