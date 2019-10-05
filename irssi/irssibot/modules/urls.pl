#!/usr/bin/perl -w
# CMDS message_public
#
use LWP::UserAgent;
use HTML::Entities;

return if (not perms("user"));
my $msg = $$irc_event{msg};
my $channel = $$irc_event{channel};

if ($msg =~ m/((?:https?\:\/\/)?[a-z0-9\-\_]+\.[a-z0-9\-\.\_]+(?:\/[^\s]+)*[^\s])/i) {
    my $m = $1;
    return if $m =~ m#\.{2,}#; #lazy fix for regexp catching "bla..." as url
    if ($$state{__urls}{$channel}{url} ne $m) {
        $$state{__urls}{$channel}{url} = $m;
        $$state{__urls}{$channel}{updated} = 0;
    }
}

if ($msg =~ m"^!@(?:\s(\-[vf]))?") {
    my $force = $1;

    my $last_url = $$state{__urls}{$channel}{url} || undef;
    my $last_update = $$state{__urls}{$channel}{updated} || undef;
    if (not defined $last_url or $last_url eq "") {
        return public("I have not seen any URLs on $channel yet.");
    }
    
    my $postfix = '';
    $last_update = 0 if $force;
    my $ttl = 300 - (time() - $last_update);
    if ($ttl <= 0) {
        ($$state{__urls}{$channel}{info}, undef) = fetchURLinfo($last_url);
        $$state{__urls}{$channel}{updated} = time();
    } else {
        $postfix = "(cached,ttl:${ttl}s)";
    }

    $postfix .= " (url: $last_url)" if $force;
    public('URL info: ' . $$state{__urls}{$channel}{info}{title} . ' ' . $postfix);
}

return;

#
#
#
#

sub fetchURLinfo {
    my ($url) = @_;
    my $ret = {};
    
    # URLs must be absolute
    $url = "http://" . $url if ($url !~ m#^https?://#);

    my $lwp = LWP::UserAgent->new;
    $lwp->max_redirect(7);
    $lwp->requests_redirectable(['GET', 'HEAD']);
    $lwp->timeout(15);
    $lwp->max_size(65535);
    $lwp->protocols_forbidden( ['file', 'mailto'] );
    $lwp->agent('lwp-request/6.15 libwww-perl/6.15');
    my $req = HTTP::Request->new(HEAD => $url);
    my $res = $lwp->request($req);
    if (!$res->is_success) {
        msg("HEAD failed on '$url'");
        msg("---- " . $res->status_line);
        $$ret{content_type} = 'text/html';

    } else {
        my $headers = $$res{_headers};
        $$ret{content_type} = $$headers{'content-type'};
        $$ret{content_type} =~ s#;.*$##;

    }

    my $content = "";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $lwp->request($req);
    if (!$res->is_success) {
        msg("GET failed on '$url'");
        msg("--- " . $res->status_line);
        $$ret{title} = 'GET failed: ' . $res->status_line;
    } else {
        $content = $res->content;
        if ($content =~ m#<title[^>]*>(.+?)<\/title#ims) {
            $$ret{title} = $1; $$ret{title} =~ s#\r?\n# #g;
            $$ret{title} =~ s#^\s+##g; $$ret{title} =~ s#\s+$##g;
        } else {
            $$ret{title} = 'no match, content-type: ' . $$ret{content_type};
        }
    }

    $$ret{title} = decode_entities($$ret{title});
    return ($ret, $content);
}
