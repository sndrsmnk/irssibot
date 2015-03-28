#!/usr/bin/perl -w
# CMDS message_topic
# CMDS previous-topic pt
#
# CMDS topic-add topic-del topic-set


# On message_topic events, this fetches the current channel topic before the topic set event was processed.
# Ergo, this holds the previous topic on topic set events.
my $chanObj = findChannel($$irc_event{channel});
my $chanObjTopic = $$chanObj{topic};


return reply("channel mode has +t and i'm not op. Sorry.")
    if (not botIsOp() and $$chanObj{mode} =~ m#t#);


# Note that $server->command("TOPIC ...") calls from this module, will trigger this module too.
if ($$irc_event{irc_event} eq "message_topic") {
    return if ($$irc_event{topic} eq $chanObjTopic);
    $$state{__topic}{$$irc_event{channel}}{previous_topic} = $chanObjTopic;
    return;
}


if ($$irc_event{cmd} =~ m#^(?:pt|previous-topic)$#i) {
    if ($$state{__topic}{$$irc_event{channel}}{previous_topic}) {
        return public("The previous topic on $$irc_event{channel} was: '".$$state{__topic}{$$irc_event{channel}}{previous_topic}."'");
    }
    return reply("no changes were seen by me.");
}


if ($$irc_event{cmd} =~ m#^topic-set#i) {
    return reply("set what, exactly?") if (($$irc_event{args} eq "") or ($$irc_event{args} =~ m#^\s+$#));
    my $new_topic = $$irc_event{args};
    $$irc_event{server}->command("TOPIC $$irc_event{channel} $new_topic");
    return;
}


if ($$irc_event{cmd} =~ m#^topic-add#i) {
    return reply("add what, exactly?") if (($$irc_event{args} eq "") or ($$irc_event{args} =~ m#^\s+$#));
    my $new_topic = $chanObjTopic . " | " . $$irc_event{args};
    $$irc_event{server}->command("TOPIC $$irc_event{channel} $new_topic");
    return;
}


if ($$irc_event{cmd} =~ m#^topic-del#i) {
    my @topicElems = split /\s\|\s/, $chanObjTopic;
    return reply("there's no elements in this topic to delete.") if scalar(@topicElems) <= 1;

    if ($$irc_event{args} =~ m#^(\d+)$#) {
        my $index = $1;
        return reply("very good!  Now start counting at 1.") if ($index == 0);
        return reply("there are only " . scalar(@topicElems) . " elements in this topic.")
            if ($index > scalar(@topicElems));

        my $removed = splice(@topicElems, $index - 1, 1);
        my $new_topic = join(" | ", @topicElems);
        $$irc_event{server}->command("TOPIC $$irc_event{channel} $new_topic");
        return;
    
    } else { # assume the arg to -del is a pattern to filter
        my @newElems = ();
        foreach my $elem (@topicElems) {
            push @newElems, $elem if ($elem !~ m#$$irc_event{args}#);
        }
        @topicElems = @newElems;
        
    }

    my $new_topic = join(" | ", @topicElems);
    $$irc_event{server}->command("TOPIC $$irc_event{channel} $new_topic");
    return;
}
