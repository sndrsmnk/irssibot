#!/usr/bin/perl -w
# CMDS message_public
#
use LWP::UserAgent;
use HTML::Entities;
use JSON;


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

if ($msg =~ m"^!@(?:\s(\-f))?") {
    my $force = $1;

    my $last_url = $$state{__urls}{$channel}{url} || undef;
    my $last_update = $$state{__urls}{$channel}{updated} || undef;
    if (not defined $last_url or $last_url eq "") {
        return public("I have not seen any URLs on $channel yet.");
    }
    
    my $postfix = '';
    $last_update = 0 if $force eq "-f";
    my $ttl = 300 - (time() - $last_update);
    if ($ttl <= 0) {
        #if ($last_url =~ m#(?:youtube.com/watch\S*v=|youtu.be/)([\w-]+)#) {
        #    $$state{__urls}{$channel}{info} = "it's a youtube video!"; #fetchYTinfo($1);
        #} else { 
            ($$state{__urls}{$channel}{info}, undef) = fetchURLinfo($last_url);
        #}
        $$state{__urls}{$channel}{updated} = time();
    } else {
        $postfix = "(cached,ttl:${ttl}s)";
    }

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
    $lwp->max_size(32768);
    $lwp->protocols_forbidden( ['file', 'mailto'] );
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


sub fetchYTinfo {
    my ($vid_id) = @_;

    my $url = "https://gdata.youtube.com/feeds/api/videos/$vid_id?v=2&alt=json";
    my (undef, $content) = fetchURLinfo($url);

    my $yt_info = from_json($content);
    $yt_info = $$yt_info{entry};

    my $ret = {};
    $$ret{title} = "Youtube fetch failed. :(";
    #return $ret if not ref $yt_info;

    my $title = $$yt_info{title}{'$t'};
    
    my $duration = text_duration($$yt_info{'media$group'}{'yt$duration'}{'seconds'});
    
    my $likes = $$yt_info{'yt$rating'}{'numLikes'};
    my $dislikes = $$yt_info{'yt$rating'}{'numDislikes'};

    my $commentcount = $$yt_info{'gd$comments'}{'gd$feedLink'}{'countHint'};
    my $viewcount = $$yt_info{'yt$statistics'}{'viewCount'};

    my $rate_avg = sprintf("%0.2f", $$yt_info{'gd$rating'}{'average'});
    my $rate_max = $$yt_info{'gd$rating'}{'max'};

    $$yt_info{'published'}{'$t'} =~ m#(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})\.#;
    my ($Y, $M, $D, $h, $m, $s) = ($1, $2, $3, $4, $5, $6);
    my $uploaded = "$D-$M-$Y";
    my $uploader = $$yt_info{'media$group'}{'media$credit'}[0]->{'yt$display'};
    
    $$ret{title} = "$title ($duration, $uploaded)  Views: $viewcount  Rating: $rate_avg/$rate_max  Dis-/Likes: $dislikes/$likes  Comments: $commentcount  Uploader: $uploader";
    return $ret;
}
