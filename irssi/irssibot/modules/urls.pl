#!/usr/bin/perl -w
# CMDS message_public
#
use LWP::UserAgent;

return if (not perms("user"));
my $msg = $$irc_event{msg};
my $channel = $$irc_event{channel};

if ($msg =~ m/((?:https?|\bwww\.)?(?::\/\/)?[a-zA-Z0-9\-\@;\/?:&=%\$_.+.Xresources',~\#]*(\([a-zA-Z0-9\-\@;\/?:&=%\$_.+.Xresources',~\#]*\)|[a-zA-Z0-9\-\@;\/?:&=%\$_+*~])+)/) {
    if ($$state{__urls}{$channel}{url} ne $1) {
        $$state{__urls}{$channel}{url} = $1;
        $$state{__urls}{$channel}{updated} = 0;
    }
}

if ($msg =~ m"^!@(?:\s(\-f))?") {
    my $force = $1;

    my $last_url = $$state{__urls}{$channel}{url} || undef;
    my $last_info = $$state{__urls}{$channel}{info} || undef;
    my $last_update = $$state{__urls}{$channel}{updated} || undef;
    if (not defined $last_url or $last_url eq "") {
        return say("I have not seen any URLs on $channel yet.");
    }

    my $postfix = '';
    $last_update = 0 if $force eq "-f";
    my $ttl = 300 - (time() - $last_update);
    if ($ttl <= 0) {
        $$state{__urls}{$channel}{info} = fetchURLinfo($last_url);
        $$state{__urls}{$channel}{updated} = time();
        $postfix = '';
    } else {
        $postfix = "(cached,ttl:${ttl}s)";
    }

    say($last_url . ': ' . $$state{__urls}{$channel}{info}{title} . ' ' . $postfix);
}

return;

#
#
#
#

sub fetchURLinfo {
    my ($url) = @_;
    my $ret = {};
   
    my $lwp = LWP::UserAgent->new;
    $lwp->max_redirect(7);
    $lwp->requests_redirectable(['GET', 'HEAD']);
    $lwp->timeout(15);
    $lwp->agent('Mozilla/5.0 (Windows NT 6.0; rv:28.0) Gecko/20100101 Firefox/28.0');
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

    if ($$ret{content_type} =~ m"text/html") {
        my $req = HTTP::Request->new(GET => $url);
        my $res = $lwp->request($req);
        if (!$res->is_success) {
            msg("GET failed on '$url'");
            msg("--- " . $res->status_line);
            $$ret{title} = 'GET failed: ' . $res->status_line;
        } else {
            my $html = $res->content;
            if ($html =~ m#<title[^>]*>(.+?)<\/title#ims) {
                $$ret{title} = $1; $$ret{title} =~ s#\r?\n# #g;
                $$ret{title} =~ s#^\s+##g; $$ret{title} =~ s#\s+$##g;
            } else {
                $$ret{title} = 'no match';
            }
        }
    } else {
        $$ret{title} = "content-type: " . $$ret{content_type};
    }

    return $ret;
}
