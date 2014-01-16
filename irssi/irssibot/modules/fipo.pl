#!/usr/bin/perl -w
# CMDS fipo
# CMDS fipostats
# CMDS fiporeset
return if (not perms("user"));

my $msg = $$irc_event{msg};
return if $msg !~ $$state{bot_triggerre};
$msg =~ s#$$state{bot_triggerre}##;

if ($msg =~ /^fipo\s*$/) {
    my @lt = localtime(time);
    my $day = sprintf("%4d%02d%02d", $lt[5]+1900, $lt[4]+1, $lt[3]);

    my $fipo_nick = "";
    $fipo_nick = $$state{__fipo}{$$irc_event{channel}}{$day}
        if exists $$state{__fipo}{$$irc_event{channel}}{$day};

    if ($fipo_nick eq "") {
        $$state{__fipo}{$$irc_event{channel}}{$day} = $$irc_event{nick};
        return say("w00t! :D");
    } else {
        return reply("Yes! :D  It was YOU!  YOU SCORED TODAY'S FIPO!!  \\o/")
            if ($$irc_event{nick} eq $fipo_nick);
    }


} elsif ($msg =~ /^fipostats\s*$/) {
    my $nick_stats = {};
    my $old_nick = undef;
    my $streak_counter = 1;

    foreach my $day (sort keys %{$$state{__fipo}{$$irc_event{channel}}}) {
        my $day_nick = $$state{__fipo}{$$irc_event{channel}}{$day};

        if ($day_nick ne $old_nick) {
            if ($streak_counter > ($$nick_stats{streaker}{count}||-1)) {
                $$nick_stats{streaker}{nick} = $old_nick || $day_nick;
                $$nick_stats{streaker}{count} = $streak_counter;
            } elsif ($streak_counter == ($$nick_stats{streaker}{count}||-1)) {
                $$nick_stats{streaker}{nick} = $$nick_stats{streaker}{nick} . " and " . $old_nick || $day_nick;
                $$nick_stats{streaker}{count} = $streak_counter;
            }

            $old_nick = $day_nick;
            $streak_counter = 1;
            $$nick_stats{$day_nick}++;
        } else {
            $streak_counter++;
            $$nick_stats{$day_nick}++;
        }
    }
    msg(Dumper(\$nick_stats));

    say("Longest streak of $$nick_stats{streaker}{count} day(s) by $$nick_stats{streaker}{nick}!");
    delete $$nick_stats{streaker};
    
    my $count = 1;
    my $msg = undef;
    foreach my $nick (
        reverse sort { $$nick_stats{$a} <=> $$nick_stats{$b} }
            keys %$nick_stats) {
        $msg .= ($msg?", $nick($$nick_stats{$nick})":"$nick($$nick_stats{$nick})");
        last if $count++ > 5;
    }

    return say("Top 5 FIPO'ers: $msg");
    

} elsif ($msg =~ /^fiporeset\s*$/) {
    return reply("no permission!") if not perms("owner");
    $$state{__fipo}{$$irc_event{channel}} = {};
    return say("Fipo stats for $$irc_event{channel} were reset.");


}
