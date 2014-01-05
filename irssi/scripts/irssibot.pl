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

    bot_trigger     => '!',
    bot_commandre   => qr/([-a-zA-Z0-9]+)(?:\s(.*))?/,

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
    # load owner module and await claiming
    load_module("owner");
}


# Put hooks on events
Irssi::signal_add_last("message public", "on_public");
Irssi::signal_add_last("message own_public", "on_public");
Irssi::signal_add_last("message private", "on_public");
Irssi::signal_add_last("message own_private", "on_public");


####
####
####


sub initialize {
    msg("Initializing.");

    $$state{dbh} = DBI->connect("dbi:mysql:mysql_read_default_file=".$ENV{HOME}."/.my.cnf:mysql_auto_reconnect=1");
    if (!$$state{dbh}) {
        msg("Fatal: can't connect to database!");
        msg("\$DBI::errstr: $DBI::errstr");
        msg("\$!: $!");
        return;
    } else {
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


sub on_public {
	my ($server, $msg, $nick, $address, $target) = @_;

    # Fiddle with values so:
    #  msgtype | target   | nick    |
    # ---------+----------+---------+
    #  public  | #channel | IRCNick |
    #  private | IRCNick  | IRCNick |
	$target = $nick if ( ! $target );
	$nick = $server->{'nick'} if ($nick =~ /^#/);
	$target = lc($target);

    # Match on bot commands
    return if ($msg !~ m#^$$state{bot_trigger}#);
    return if ($msg !~ $$state{bot_commandre});
    my $command = $1; my $args = $2 || "";

    # Fetch user information from DB
    $$state{user_info} = {};
    my $user_data = $$state{dbh}->selectrow_hashref("SELECT h.hostmask AS current_hostmask, u.* FROM ib_hostmasks h, ib_users u WHERE h.users_id = u.id AND h.hostmask = ?;", undef, $address);
    if (ref($user_data) eq 'HASH') {
        $$state{user_info}{$_} = $$user_data{$_} foreach keys %$user_data;
        $$state{user_info}{permissions} = $$state{dbh}->selectcol_arrayref("SELECT permission FROM ib_perms WHERE users_id = ?", undef, $$state{user_info}{id});
        $$state{user_info}{hostmasks} = $$state{dbh}->selectcol_arrayref("SELECT hostmask FROM ib_hostmasks WHERE users_id = ?", undef, $$state{user_info}{id});
    }

    # Look for a command matching the one on irc
    my $claimed = 0;
MODULE: foreach my $module (sort keys %{$$state{modules}}) {
        foreach my $module_command (sort { length($a) <=> length($b) } keys %{$$state{modules}{$module}{command}}) {
            if ($command eq $module_command) {

                my $log_txt = "Module ${module}::${module_command} for $nick/$target";
                if (exists $$state{user_info}{ircnick}) {
                    $log_txt .= ", user " . $$state{user_info}{ircnick} . " with perms: " . join(", ", @{$$state{user_info}{permissions}});
                } else {
                    $log_txt .= ", unrecognised user.";
                }
                msg($log_txt);

                my $code = load_module($module);
                eval {
                    $code->( {
                        cmd      => $command,
                        args     => $args,
                        server   => $server,
                        msg      => $msg,
                        nick     => $nick, 
                        address  => $address,
                        hostmask => $nick . '!' . $address,
                        target   => $target
                    } );
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

    if (not $claimed) {
        msg("No module claimed the '$command' command with '$args' arguments.");
    }
}





###
###
### libs/ stuff
###

sub clean_eval { return eval shift; }
sub load_module {
    my ($filename) = @_;
    $filename .= ".pl" if ($filename !~ m#\.pl#);
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
            my @codestring = (
                'sub {',
                    'local %_ = %{ +shift };',
                    "#line 1 $module",
            );
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
            push @codestring, '}';
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

sub reply { $_{server}->command("msg $_{target} $_{nick}, $_") for @_ }
sub say   { $_{server}->command("msg $_{target} $_") for @_ }
sub tell  { $_{server}->command("msg $_{nick} $_") for @_ }
sub match { $_{server}->masks_match("@_", $_{nick}, $_{address}) }
sub perms {
    return 1 if (match($$state{bot_ownermask}));

    my @wanted_perms = @_;
    goto AUTHFAIL if (not exists $$state{user_info}{ircnick});
    foreach my $perm (@{$$state{user_info}{permissions}}) {
        goto AUTHOK if (grep(/^$perm$/, @wanted_perms));
    }

AUTHFAIL:
    say("Access to this module is restricted to members of: ".join(", ", @wanted_perms).".");
    msg("Rejected access to '!$_{cmd}' (args:'$_{args}') from '$_{hostmask}'.");
    return 0;

AUTHOK:
    return 1;
}
