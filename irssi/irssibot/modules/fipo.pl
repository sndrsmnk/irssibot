#!/usr/bin/perl -w
# CMDS fipo
# CMDS fipostats
# CMDS fiporeset
# CMDS fiposet
return if (not perms("user"));

my $msg = $$irc_event{msg};
return if $msg !~ $$state{bot_triggerre};
$msg =~ s#$$state{bot_triggerre}##;

$$irc_event{channel} = "#cistron" if $$irc_event{channel} eq "#irssibot";

if ($msg =~ /^fipostats(?:\s+.*)?/) {
    my $oldnick = my $streaknick = ""; my @winningstreaknick = ();
    my $streak = my $winningstreak = 1; my $nick_stats = {};
    foreach my $day (sort keys %{$$state{__fipo}{$$irc_event{channel}}}) {
        my $nick = $$state{__fipo}{$$irc_event{channel}}{$day};
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
    say("Longest streak of $winningstreak day(s) by " . join(", ", @winningstreaknick) . "!");
    
    my $count = 1;
    my $msg = undef;
    foreach my $nick (
        reverse sort { $$nick_stats{$a} <=> $$nick_stats{$b} }
            keys %$nick_stats) {

        # prevent hilights
        my @letters = split(//, $nick);
        my $out_nick = shift @letters;
        $out_nick .= "\0030\003";
        $out_nick .= join("", @letters);

        $msg .= ($msg?", $out_nick($$nick_stats{$nick})":"$out_nick($$nick_stats{$nick})");
        last if $count++ >= 5;
    }
    $count--; # meh.

    return say("Top $count FIPO'ers: $msg");
    

} elsif ($msg =~ /^fiporeset\s*$/) {
    return reply("no permission!") if not perms("owner");
    $$state{__fipo}{$$irc_event{channel}} = {};
    return say("Fipo stats for $$irc_event{channel} were reset.");


} elsif ($msg =~ /^fiposet\s*([^\s]+)\s(.*)$/) {
    return reply("no permission!") if not perms("owner");
    my $date = $1; my $nick = $2;
    $$state{__fipo}{$$irc_event{channel}}{$date} = $nick;
    save_configuration();
    return say("fipo for $date set to $nick!");

} elsif ($msg =~ /^fipo(?:\s+.*)?/) {
    my @lt = localtime(time);
    my $day = sprintf("%4d%02d%02d", $lt[5]+1900, $lt[4]+1, $lt[3]);

    my $fipo_nick = "";
    $fipo_nick = $$state{__fipo}{$$irc_event{channel}}{$day}
        if exists $$state{__fipo}{$$irc_event{channel}}{$day};

    if ($fipo_nick eq "") {
        $$state{__fipo}{$$irc_event{channel}}{$day} = $$irc_event{nick};
        save_configuration();
        return say("w00t! :D");
    } else {
        return reply("Yes! :D  It was YOU!  YOU SCORED TODAY'S FIPO!!  \\o/")
            if ($$irc_event{nick} eq $fipo_nick);
    }

}
