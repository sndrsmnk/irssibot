#!/usr/bin/perl -w
#
# irssibot (c) GPLv2 2014 S. Smeenk <irssi@freshdot.net>
# $Id$
#
# Because existing IRC-bots suck
# Some of this is based on http://www.perlmonks.org/bare/?node_id=180805 but this is better, ofcourse.
# 
use Irssi;
use Irssi::Irc;
use DBI;
use Data::Dumper;
use Time::HiRes qw[gettimeofday tv_interval];
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
    bot_commandre   => qr/([-a-zA-Z0-9]+)(?:\s(.*)|$)/, # this must return the cmd in $1 and the rest in $2

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
    $irc_event =~ s/\s/_/g;

    # This ref will be passed to the module $code ref
    # and should contain all available information from
    # Irssi, see the for-loops and doc/irssi/signals.txt.gz
    my $code_args = {
        irc_event => $irc_event,
    };


########################################################################
    if ($irc_event =~ m#channel_mode_changed#) {
        for my $event_arg (qw(channel setby)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#default_event_numeric#) {
        for my $event_arg (qw(server data nick address)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_invite#) {
        for my $event_arg (qw(server channel nick address)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_irc_(?:own_)?action#) {
        for my $event_arg (qw(server msg nick address target)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_irc_(?:own_)?ctcp#) {
        for my $event_arg (qw(server cmd data nick address target)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_irc_(?:own_)?notice#) {
        for my $event_arg (qw(server msg nick address target)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_irc_mode#) {
        for my $event_arg (qw(server channel nick address mode)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_irc_op_public#) {
        for my $event_arg (qw(server msg nick address target)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_join#) {
        for my $event_arg (qw(server channel nick address)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_kick#) {
        for my $event_arg (qw(server ichannel nick kicker address reason)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_nick#) {
        for my $event_arg (qw(server newnick oldnick address)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_part#) {
        for my $event_arg (qw(server channel nick address reason)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_quit#) {
        for my $event_arg (qw(server nick address reason)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_topic#) {
        for my $event_arg (qw(server channel topic nick address)) {
            $$code_args{$event_arg} = shift;
        }


########################################################################
    } elsif ($irc_event =~ m#message_(?:own_)?public#) {
        for my $event_arg (qw(server msg nick address target)) {
            $$code_args{$event_arg} = shift;
        }

        # See if the IRC message matches the bot trigger and command
        # regexps. This passes the raw event through to modules otherwise.
        if (($$code_args{msg} =~ $$state{bot_triggerre}) and ($$code_args{msg} =~ $$state{bot_commandre})) {
            $$code_args{cmd} = $1;
            $$code_args{args} = $2 || "";
            $$code_args{args} =~ s/^\s+//g; $$code_args{args} =~ s/\s+$//g;
        }


########################################################################
    } else {
        msg("IRC event '$irc_event' was not handled. Oops.");
        return;

    }


    # Look for a module & command matching the event on irc
MODULE: foreach my $module (sort keys %{$$state{modules}}) {
        foreach my $command (sort { length($a) <=> length($b) } keys %{$$state{modules}{$module}{command}}) {
            $$code_args{trigger} = '';
            if ($command eq $irc_event) {
                $$code_args{trigger} = 'irc_event';
            } elsif ($command eq $$code_args{cmd}) {
                $$code_args{trigger} = 'module_command';
            }
            next if ((not defined $$code_args{trigger}) or ($$code_args{trigger} eq ""));

            # Fetch user_info from database if $address is available.
            # This is used in perm() access controls.
            $$state{user_info} = getUserInfo($$code_args{address}) if defined $$code_args{address};

            # Ensures sane values for keys in the code_args ref for events.
            $$code_args{nick} = $server->{'nick'} if ($$code_args{nick} =~ /^[&#]/);
            $$code_args{target} ||= $$code_args{nick};
            $$code_args{target} = lc($$code_args{target});
            $$code_args{channel} = $$code_args{target} if not exists $$code_args{channel};

            # Bot nick and op-state
            $$state{bot_nick} = $$code_args{server}->{nick} if defined $$code_args{server};
            $$state{bot_address} = $$code_args{server}->{address} if defined $$code_args{server};
            $$state{bot_is_op} = botIsOp($$code_args{channel}) if defined $$code_args{channel};

            my $t_start = [gettimeofday];
            my $code = load_module($module);
            eval {
                $code->( $code_args );
            };
            if ($@) {
                msg("Module '$command' exec gave output:");
                msg($_) foreach $@;
            }
            my $t_end = [gettimeofday];
            my $t_str = sprintf("[%0.2fsec]", tv_interval($t_start, $t_end));

            my $log_txt = "Module ${module}::${command} ($$code_args{trigger}) $t_str";
            $log_txt .= $$code_args{nick} ? " for $$code_args{nick}" : " for nick_unset";
            $log_txt .= $$code_args{address} ? "!$$code_args{address}" : "!address_unset";
            $log_txt .= $$code_args{target} ? "/$$code_args{target}" : "/target_unset";
            if (exists $$state{user_info}{ircnick}) {
                $log_txt .= ", user " . $$state{user_info}{ircnick};

            } else {
                $log_txt .= ", unrecognised user.";
            }
            msg($log_txt);

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
        $$state{dbh}->{RaiseError} = 0;
        $$state{dbh}->{mysql_auto_reconnect} = 1;
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


sub getUserInfo {
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
    return 0 if (not exists $$state{user_info}{permissions});
    foreach (@_) { return 1 if exists $$state{user_info}{permissions}{global}{$_}; }
    foreach (@_) { return 1 if exists $$state{user_info}{permissions}{$$state{act_channel}}{$_}; }
    return 0;
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

sub botIsOp {
    my $i_am_op = 0;
    foreach my $channel (Irssi::channels()) {
        next if ($$channel{name} ne $$irc_event{channel});
        foreach my $nick ($channel->nicks()) {
            if ($nick->{nick} eq $$irc_event{server}->{nick}) {
                $i_am_op = 1 if ($$nick{op} == 1);
            }
        }
    }
    return $i_am_op;
}
