#!/usr/bin/perl -w
# CMDS fipo
# CMDS fipostats
# CMDS fiporeset
# CMDS fiposet
return if (not perms("user"));

my $msg = $$irc_event{msg};
return if $msg !~ $$state{bot_triggerre};
$msg =~ s#$$state{bot_triggerre}##;

if ($msg =~ /^fipostats\s?(.*)/) {
    my $lookupnick = $1; $lookupnick =~ s/[\s\004\003\002\001]*//g;

    my $oldnick = my $streaknick = ""; my @winningstreaknick = ();
    my $streak = my $winningstreak = 1; my $nick_stats = {};
    foreach my $day (sort keys %{$$state{fipo}{$$irc_event{channel}}}) {
        my $nick = $$state{fipo}{$$irc_event{channel}}{$day};

        $$nick_stats{$nick}++;

        if ($nick eq $oldnick) {
            $streak++;
            $streaknick = $nick;
        } else {
            if ($streak > $winningstreak) {
                $winningstreak = $streak;
                @winningstreaknick = ( $streaknick );
            } elsif ($streak == $winningstreak) {
                push @winningstreaknick, $streaknick unless grep { /^$streaknick$/ } @winningstreaknick;
            }
            $streak = 1;
            $streaknick = $nick;
            $oldnick = $nick;
        }
    }
    # check again at end of loop. streak might be 'in progress'... 
    if ($streak > $winningstreak) {
        $winningstreak = $streak;
        @winningstreaknick = ( $streaknick );
    } elsif ($streak == $winningstreak) {
        push @winningstreaknick, $streaknick unless grep { /^$streaknick$/ } @winningstreaknick;
    }

    if ($lookupnick) {
        if ($$nick_stats{$lookupnick}) {
            public(((${lookupnick}eq$$irc_event{nick})?"You":${lookupnick}) . " scored $$nick_stats{$lookupnick} fipo's with a longest streak of [E_NOTIMPL] day(s)!");
        } else {
            public("${lookupnick} did not score any fipo's!");
        }
    } else {
        public("Longest streak of $winningstreak day(s) by " . join(", ", @winningstreaknick) . "!");
    }
    
    my $count = 1;
    my $msg = undef;
    foreach my $nick (
        reverse sort { $$nick_stats{$a} <=> $$nick_stats{$b} }
            keys %$nick_stats) {

        # prevent hilights
        my @letters = split(//, $nick);
        my $out_nick = shift @letters;
        $out_nick .= "\0030\003\002\002";
        $out_nick .= join("", @letters);

        $msg .= ($msg?", $out_nick($$nick_stats{$nick})":"$out_nick($$nick_stats{$nick})");
        last if $count++ >= 5;
    }
    $count--; # meh.

    public("Top $count FIPO'ers: $msg") unless $lookupnick;
    return
    

} elsif ($msg =~ /^fiporeset\s*$/) {
    return reply("no permission!") if not perms("owner");
    $$state{fipo}{$$irc_event{channel}} = {};
    return public("Fipo stats for $$irc_event{channel} were reset.");


} elsif ($msg =~ /^fiposet\s*([^\s]+)\s(.*)$/) {
    return reply("no permission!") if not perms("owner");
    my $date = $1; my $nick = $2;
    $$state{fipo}{$$irc_event{channel}}{$date} = $nick;
    save_configuration();
    return public("fipo for $date set to $nick!");

} elsif ($msg =~ /^fipo(?:\s+.*)?/) {
    my @lt = localtime(time);
    my $day = sprintf("%4d%02d%02d", $lt[5]+1900, $lt[4]+1, $lt[3]);

    my $fipo_nick = "";
    $fipo_nick = $$state{fipo}{$$irc_event{channel}}{$day}
        if exists $$state{fipo}{$$irc_event{channel}}{$day};

    if ($fipo_nick eq "") {
        $$state{fipo}{$$irc_event{channel}}{$day} = $$state{user_info}{ircnick};
        save_configuration();
        return public("w00t! :D");
    } else {
        return reply("Yes! :D  It was YOU!  YOU SCORED TODAY'S FIPO!!  \\o/")
            if ($$state{user_info}{ircnick} eq $fipo_nick);
    }

}
