#!/usr/bin/perl -w
#
# irssibot (c) GPLv2 2014 S. Smeenk <irssi@freshdot.net>
#
# Because existing IRC-bots suck
# Some of this is based on http://www.perlmonks.org/bare/?node_id=180805 but this is better, ofcourse.
# 
use Irssi;
use Irssi::Irc;
use DBI;
use Data::Dumper;
umask 077;

$VERSION = "0.1alpha";
%IRSSI = (
    authors     => 'Sander Smeenk',
    contact     => 'irssi@freshdot.net',
    name        => 'irssibot',
    description => 'IRC bot implementation based on irssi',
    license     => 'GNU GPLv2 or later',
    url         => 'http://www.freshdot.net/',
);


our $state = {
    bot_basepath    => $ENV{HOME} . '/.irssi/irssibot',
    bot_modulepath  => $ENV{HOME} . '/.irssi/irssibot/modules',
    bot_configfile  => $ENV{HOME} . '/.irssi/irssibot/irssibot-config.pl',

    bot_triggerre   => qr/^!/, # 'trigger char' for module commands
    bot_commandre   => qr/([-a-zA-Z0-9]+)(?:\s(.*))?/, # this must return the cmd in $1 and the rest in $2

    bot_uniqueid    => join("", (0..9, 'A'..'Z', 'a'..'z')[rand 62, rand 62, rand 62, rand 62, rand 62, rand 62, rand 62, rand 62]),
    last_output     => 0,
    modules         => {},
};


if (not -d $$state{bot_basepath}) {
    mkdir $$state{bot_basepath};
    msg("Irssibot basepath " . $$state{bot_basepath} . " created.");
}

if (not -e $$state{bot_configfile}) {
    msg("Irssibot configuration file was not found.");
    msg("");
    msg("My Unique ID is currently " . $$state{bot_uniqueid});

} else {
    load_configuration();
    msg("State was restored from $$state{bot_configfile}");
    msg("");
    msg("My Unique ID is currently " . $$state{bot_uniqueid});
}

if (exists $$state{bot_ownermask} and $$state{bot_ownermask} ne "") {
    msg("My owner is " . $$state{bot_ownermask});
    msg("");
    initialize();

} else {
    msg("I have no owner.");
    msg("");
    msg("Use the Unique ID with '!owner ...' on IRC to claim this bot.");
    msg("");
    msg("Until claimed, only the 'owner' module will be loaded,");
    msg("after claiming the other modules will be autoloaded.");
    msg("A basic configuration file will then be created for you.");
    msg("");
    load_module("owner");
}


# IRC events
foreach my $event (
        'channel mode changed',
        'default event numeric',
        'message invite',
        'message irc action',
        'message irc ctcp',
        'message irc mode',
        'message irc notice',
        'message irc op_public',
        'message irc own_action',
        'message irc own_ctcp',
        'message irc own_notice',
        'message join',
        'message kick',
        'message nick',
        'message own_nick',
        'message own_public',
        'message part',
        'message public',
        'message quit',
        'message topic',
        'message_own_private',
        'message_private',
    ) {

    Irssi::signal_add_last($event, sub { dispatch_irc_event($event, @_); });

}


####
####
####


sub dispatch_irc_event {
    my $irc_event = shift;

    # Default value for module_command is irc event type.
    # Private/public message events override this with
    # the command matched from the !trigger on IRC.
    my $module_command = $irc_event;
    $module_command =~ s#\s#_#g;

    # This ref will be passed to the module $code ref
    # and should contain all available information from
    # Irssi, see the for-loops and doc/irssi/signals.txt.gz
    my $code_args = {
        irc_event => $irc_event,
    };


########################################################################
    if ($irc_event =~ m#channel mode changed#) {
        for my $event_arg (qw(channel setby)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#default event numeric#) {
        for my $event_arg (qw(server data nick address)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message invite#) {
        for my $event_arg (qw(server channel nick address)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message irc (?:own_)?action#) {
        for my $event_arg (qw(server msg nick address target)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message irc (?:own_)?ctcp#) {
        for my $event_arg (qw(server cmd data nick address target)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message irc (?:own_)?notice#) {
        for my $event_arg (qw(server msg nick address target)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message irc mode#) {
        for my $event_arg (qw(server channel nick address mode)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message irc op_public#) {
        for my $event_arg (qw(server msg nick address target)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message join#) {
        for my $event_arg (qw(server channel nick address)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message kick#) {
        for my $event_arg (qw(server ichannel nick kicker address reason)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message nick#) {
        for my $event_arg (qw(server newnick oldnick address)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message part#) {
        for my $event_arg (qw(server channel nick address reason)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message quit#) {
        for my $event_arg (qw(server nick address reason)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message topic#) {
        for my $event_arg (qw(server channel topic nick address)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message (?:own_)?public#) {
        for my $event_arg (qw(server msg nick address target)) {
            $$code_args{$event_arg} = shift;
        }

        # Rewrite $module_command if the IRC message matches
        # the bot trigger and command regexps. This passes
        # the raw event through to modules otherwise.
        if (($$code_args{msg} =~ $$state{bot_triggerre}) and ($$code_args{msg} =~ $$state{bot_commandre})) {
            $module_command = $1; $$code_args{args} = $2 || "";
            $$code_args{args} =~ s/^\s+//g; $$code_args{args} =~ s/\s+$//g;
        }


########################################################################
    } else {
        msg("IRC event '$irc_event' was not handled. Oops.");
        return;

    }

    # Fetch user_info from database if $address is available.
    # This is used in perm() access controls.
    $$state{user_info} = updateUserInfo($$code_args{address}) if defined $$code_args{address};

    # For perms(), we need to know the channel if available.
    # Fallback to target, or set undefined.
    $$state{act_channel} = $$code_args{channel}?$$code_args{channel}:($$chanel_args{target}?$$channel_args{target}:'__undef');

    # Ensures sane values for 'nick' and 'target' in the code_args
    # ref for events where 'our own' events are routed to the bot.
    if (defined $$code_args{nick} or not defined $$code_args{target}) {
        $$code_args{nick} = $server->{'nick'} if ($$code_args{nick} =~ /^#/);
        $$code_args{target} ||= $$code_args{nick};
        $$code_args{target} = lc($$code_args{target});
    }

    my $log_txt = ""; 
    $log_txt = $$code_args{nick} ? "for $$code_args{nick}" : "for nick_unset";
    $log_txt .= $$code_args{address} ? "!$$code_args{address}" : "!address_unset";
    $log_txt .= $$code_args{target} ? "/$$code_args{target}" : "/target_unset";
    if (exists $$state{user_info}{ircnick}) {
        $log_txt .= ", user " . $$state{user_info}{ircnick};

    } else {
        $log_txt .= ", unrecognised user.";
    }

    # Look for a module & command matching the event on irc
    my $claimed = 0;
MODULE: foreach my $module (sort keys %{$$state{modules}}) {
        foreach my $command (sort { length($a) <=> length($b) } keys %{$$state{modules}{$module}{command}}) {
            if ($module_command eq $command) {

                $log_txt = "Module ${module}::${command} " . $log_txt;
                msg($log_txt);

                my $code = load_module($module);
                eval {
                    $code->( $code_args );
                };
                if ($@) {
                    msg("Module '$command' exec gave output:");
                    msg($_) foreach $@;
                }

                # Stop command processing as match was found;
                $claimed++;
                last MODULE;
            }
        }
    }
}




###
###
### libs/ stuff
###


sub clean_eval { return eval shift; }
sub load_module {
    my ($filename) = @_;
    $filename .= ".pl" if ($filename !~ m#\.pl$#);
    my $module_file = $$state{bot_basepath} . "/modules/" . $filename;
    my $module = $module_file;
    $module =~ s#.*/##; $module =~ s#\.pl$##;

    if (not -e $module_file) {
        msg("Request to load module '$module' but '$module_file' does not exist.");
        delete $$state{modules}{$module} if exists $$state{modules}{$module};
        return undef;
    }

    my $mtime = (stat "$module_file")[9];
    my $log_text = "";
    if ($mtime > $$state{modules}{$module}{mtime}) {
        if (exists $$state{modules}{$module}{mtime}) {
            $log_text = "Updating module";
        } else {
            $log_text = "Loading new module";
        }

        # File was updated, so reload.
        delete $$state{modules}{$module};

        if (open my $fh, "$module_file") {
            my @codestring = ( 'sub { local $irc_event = +shift; ' );
            while (my $line = <$fh>) {
                if ($line =~ m/# CMDS ([^#]+)$/) {
                    my $module_cmds = $1;
                    if ($module_cmds =~ $$state{bot_commandre}) {
                        foreach my $command (split(/\s+/, $module_cmds)) {
                            $$state{modules}{$module}{command}{$command}++;
                        }
                    }
                    next;
                }
                next if $line =~ m/^\s*#/;
                next if $line =~ m/^\s*$/;
                push @codestring, $line;
            }
            push @codestring, '}'; # closes the 'sub {'
            $$state{modules}{$module}{code} = clean_eval join "\n", @codestring;
            if (ref($$state{modules}{$module}{code}) ne "CODE") {
                msg("Errors while loading module '$module'. It was unloaded:");
                msg($_) for $@;
                delete $$state{modules}{$module};
                return undef;
            }

            $$state{modules}{$module}{mtime} = $mtime;

            if (not scalar keys(%{$$state{modules}{$module}{command}})) {
                msg("Module '$module' does not declare any CMDS. It was unloaded.");
                delete $$state{modules}{$module};
                return undef;

            } else {
                my $commands_text = join ", ", keys %{$$state{modules}{$module}{command}};
                msg("$log_text [$module]: $commands_text");

            }

        } else {
            msg("Can't read '$module' in '$module_file': $!\n");

        }
    }

    # Code in $$state is (still?) fresh
    return $$state{modules}{$module}{code};
}


sub unload_module {
    my ($module) = @_;
    if (exists $$state{modules}{$module}) {
        msg("Unloaded module '$module'.");
        delete $$state{modules}{$module} if exists $$state{modules}{$module};
    } else {
        msg("No module found with name '$module'.");
        my $modules_text = join ", ", keys %{$$state{modules}};
        msg("Currently loaded: $modules_text");
    }
}


sub initialize {
    msg("Initializing.");

    $$state{dbh} = DBI->connect("dbi:mysql:mysql_read_default_file=".$ENV{HOME}."/.my.cnf:mysql_auto_reconnect=1");
    if (!$$state{dbh}) {
        msg("Fatal: can't connect to database!");
        msg("\$DBI::errstr: $DBI::errstr");
        msg("\$!: $!");
        return;
    } else {
        $$state{dbh}->{RaiseError} = 0; # :>
        msg("Database connection OK");
    }

    if (-d $$state{bot_modulepath}) {
        opendir(DIR, $$state{bot_modulepath});
        my @modules = grep { /\.pl$/ } readdir(DIR);
        closedir(DIR);
        foreach my $module (@modules) { load_module($module); }
        msg("");
        msg("Modules loaded: " . join(', ', keys %{$$state{modules}}));
    } else {
        msg("No module directory '$$state{bot_modulepath}' found!");
    }

    msg("");
}


sub updateUserInfo {
    my ($address) = @_;

    return msg("No database connection.") if (not defined $$state{dbh});

    # Fetch user information from DB
    my $ret = {};
    my $user_data = $$state{dbh}->selectrow_hashref("SELECT h.hostmask AS current_hostmask, u.* FROM ib_hostmasks h, ib_users u WHERE h.users_id = u.id AND h.hostmask = ?;", undef, $address);
    return $ret if (ref($user_data) ne 'HASH');
    $$ret{$_} = $$user_data{$_} foreach keys %$user_data;

    # Include global and per-channel permissions
    my $sth = $$state{dbh}->prepare("SELECT permission, channel FROM ib_perms WHERE users_id = ?");
    $sth->execute($$ret{id});
    while (my $row = $sth->fetchrow_hashref()) {
        if (defined $$row{channel} and $$row{channel} ne '') {
            $$ret{permissions}{$$row{channel}}{$$row{permission}}++;
        } else {
            $$ret{permissions}{global}{$$row{permission}}++;
        }
    }
    $sth->finish();

    # And all known hostmasks while we're at it
    $$ret{hostmasks} = $$state{dbh}->selectcol_arrayref("SELECT hostmask FROM ib_hostmasks WHERE users_id = ?", undef, $$state{user_info}{id});

    return $ret;
}


sub load_configuration {
    open (FD, "<$$state{bot_configfile}") or die "Problems while reading configuration file: $!\n";
    my $blob = "";
    { local $/ = undef; $blob = <FD>; close(FD); }
    $state = eval "my " . $blob;
    msg("Irssibot configuration file was loaded.");
}


sub save_configuration {
    open (FD, ">$$state{bot_configfile}") or die "Problems while writing configuration file: $!\n";
    my $temp = $state;
    delete $$temp{modules};
    print FD Dumper($temp);
    $temp = {}; undef $temp;
    close(FD);
    msg("Irssibot configuration file was saved.");
}


sub msg {
    my ($msg, $lvl) = @_;
    if (!$lvl) { $lvl = MSGLEVEL_CRAP }

    if ($$state{last_output} < int(time() - 10)) {
        $$state{last_output} = time();
        msg("");
        msg("--] irssibot [--------------------------------------------------------");
    }

    foreach my $window (Irssi::windows()) {
        if ($window->{name} eq 'irssibot') {
            $window->print($msg, $lvl);
            $$state{last_output} = time();
            return;
        }
    }

    Irssi::print("$msg", $lvl);
    $$state{last_output} = time();
}



####
####
#### Helper functions for modules/

sub reply { $$irc_event{server}->command("msg $$irc_event{target} $$irc_event{nick}, $_") for @_ }
sub say   { $$irc_event{server}->command("msg $$irc_event{target} $_") for @_ }
sub tell  { $$irc_event{server}->command("msg $$irc_event{nick} $_") for @_ }
sub match { $$irc_event{server}->masks_match("@_", $$irc_event{nick}, $$irc_event{address}) }
sub perms {
    return 1 if (match($$state{bot_ownermask}));
    goto AUTHFAIL if (not exists $$state{user_info}{ircnick});

    my @wanted_perms = @_;
    foreach my $perm (@{$$state{user_info}{permissions}{global}}) {
        goto AUTHOK if (grep(/^$perm$/, @wanted_perms));
    }
    foreach my $perm (@{$$state{user_info}{permissions}{$$state{act_channel}}}) {
        goto AUTHOK if (grep(/^$perm$/, @wanted_perms));
    }

AUTHFAIL:
    say("Access to this module is restricted to members of: ".join(", ", @wanted_perms).".");
    msg("Rejected access to '!$$irc_event{cmd}' (args:'$$irc_event{args}') from '$$irc_event{nick}!$$irc_event{address}'.");
    return 0;

AUTHOK:
    return 1;
}


sub isChannel {
    my ($check_channel) = @_;
    foreach my $channel (Irssi::channels()) {
        next if ($$channel{name} ne $check_channel);
        foreach my $nick ($channel->nicks()) {
            if ($nick->{nick} eq $$irc_event{server}->{nick}) {
                return 1;
            }
        }
    }
    return 0;
}
