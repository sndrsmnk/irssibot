#!/usr/bin/perl -
# CMDS vid
#
# Parses VID.nl's 'overzicht' page!
#   http://www.vid.nl/VI/overzicht
#
# !vid
# !vid A12
# !vid -a
#
use LWP::UserAgent;


return if (not perms("user"));


my $vidContent = "";
my $vid_overzicht = "[geen info, parser fout]";

$vidContent = fetchURL("http://www.vid.nl/VI/overzicht");
if ($vidContent =~ m#<div.+?overzicht-aantal">(.+?)</div>#) {
    $vid_overzicht = $1;
}
$vidContent =~ s#^.*(<div id="overzicht-verkeer".*</div>).+?<div id="overzicht-ov".*#$1#s;
my @vidInfo = parse_vidContent($vidContent);


if ($$irc_event{cmd} eq 'vid' and $$irc_event{args} ne "") {
    my $said_something = 0;
    foreach my $elem (@vidInfo) {
        next if (lc($$elem{wegnr}) ne lc($$irc_event{args}));

        my $txt =
            ($$elem{wegnr}ne""?"$$elem{wegnr} ":"") .
            ($$elem{hoofdtraject}ne""?"$$elem{hoofdtraject} ":"") .
            $$elem{traject};

        $txt =~ s/^\s+//; $txt =~ s/\s+$//;

        if (defined $$elem{lengte}) {
            $txt .= ", lengte " . $$elem{lengte} . " (" . $$elem{file_staat} . ")"
        }

        $txt .= ": " . $$elem{bericht};

        public(ucfirst($txt));
        $said_something++;
    }
    public("Geen meldingen.") if not $said_something;


} elsif ($$irc_event{cmd} eq 'vid' and $$irc_event{args} eq "") {
    my $wegen = {};
    foreach my $elem (@vidInfo) {
        $$wegen{$$elem{wegnr}}{aantal}++;
        if (defined $$elem{lengte}) {
            $$elem{lengte} =~ tr/a-z//d;
            $$wegen{$$elem{wegnr}}{lengte} += $$elem{lengte};
        }
    }

    my $txt = "";
    foreach my $wegnr (sort keys %$wegen) {
        $txt .= "$wegnr (" . $$wegen{$wegnr}{aantal};
        if (defined $$wegen{$wegnr}{lengte}) {
            $txt .= ", file ".$$wegen{$wegnr}{lengte}."km";
        }
        $txt .= "), ";
    }
    $txt =~ s#,\s+$##;
    
    public("$vid_overzicht: $txt");
}



#
#
#
#



sub parse_vidContent {
    my ($vidContent) = @_;

    my @ret_array = ();

    my $prev_wegnr = my $prev_hoofdtraject = "";
    while ($vidContent =~ m#<dl>(.+?)</dl>#gs) {
        my $fileContent = $1;

        my $vid = {
            'wegnr' => '',
            'hoofdtraject' => '',
            'traject' => '',
            'soort' => '',
            'file_staat' => '',
            'lengte' => undef,
            'bericht' => '',
        };

        if ($fileContent =~ m#"vi-hoofdtraject.+?vi-wegnr">(.+?)</span>(.+?)</dt>#s) {
            $$vid{wegnr} = $1;
            $$vid{hoofdtraject} = $2;
            $prev_wegnr = $$vid{wegnr};
            $prev_hoofdtraject = $$vid{hoofdtraject};
        } else {
            $$vid{wegnr} = $prev_wegnr;
            $$vid{hoofdtraject} = '';
        }

        if ($fileContent =~ m#"vi-(gebied|traject).+?">(.+?)</d[dt]>#s) {
            my ($type, $value) = ($1, $2);
            $type = 'wegnr' if $type eq 'gebied';
            $$vid{$type} = $value;
            $$vid{$type} =~ s#<a href=.+?</a>##s; # strip camera url
            $$vid{$type} =~ s#<.+?>##g; 
        }

        if ($fileContent =~ m#"vi-(bericht|langdurig).+?">(.*)</dd>#s) {
            $$vid{soort} = $1;
            my $berichtContent = $2;

            if ($berichtContent =~ s#.+?"vid-sprite vs-file-(\w+)">\s+</span>##s) {
                my $state = $1;
                $$vid{file_staat} = $state;
                $$vid{file_staat} = 'onveranderd' if ($state eq "leeg");
                $$vid{file_staat} = 'ongeval' if ($state eq "excl");
                $$vid{file_staat} = 'afnemend' if ($state eq "down");
                $$vid{file_staat} = 'toenemend' if ($state eq "up");
                $$vid{file_staat} = 'gelijkblijvend' if ($state eq "same");
            }

            if ($berichtContent =~ s#.+?"vi-km.+?>(.+?)</span>##s) {
                $$vid{lengte} = $1;
            }

            $berichtContent =~ s#<.+?>##g;
            $berichtContent =~ s#\r?\n##g;
            $berichtContent =~ s#\s{2,}# #g;
            $berichtContent =~ s#^\s+##g;
            $berichtContent =~ s#\s+$##g;
            $berichtContent =~ s#omleiding ingesteld#, omleiding ingesteld.#;
            $berichtContent =~ s#vertraging de vertraging is ongeveer#vertraging: ca.#;
            $$vid{bericht} = $berichtContent;
        }

        push @ret_array, $vid;
    }

    return @ret_array;
}


sub fetchURL {
    my ($url) = @_;
    my $ret = "";

    # URLs must be absolute
    $url = "http://" . $url if ($url !~ m#^https?://#);

    my $lwp = LWP::UserAgent->new;
    $lwp->max_redirect(7);
    $lwp->requests_redirectable(['GET', 'HEAD']);
    $lwp->timeout(15);
    $lwp->agent('Mozilla/5.0 (Windows NT 6.0; rv:34.0) Gecko/20100101 Firefox/34.0');
    my $req = HTTP::Request->new(GET => $url);
    my $res = $lwp->request($req);
    if (!$res->is_success) {
        msg("GET failed on '$url'");
        msg("---- " . $res->status_line);

    } else {
        $ret = $res->content;

    }

    return $ret;
}

