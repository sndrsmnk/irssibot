#!/usr/bin/perl -w
# CMDS wolfram w
# CMDS gcalc calc
#
use LWP::UserAgent;
use URI::Escape;
use XML::XPath;
use XML::XPath::XMLParser;

my $wolfram_app_id = "";
{
    # Fix old appid config.
    if (exists $$state{__wolfram} and exists $$state{__wolfram}{appid}) {
        msg("Wolfram updating configuration.");
        $$state{wolfram_appid} = $$state{__wolfram}{appid};
        delete $$state{__wolfram};
        save_configuration();
    }
}
$wolfram_app_id = (exists $$state{wolfram_appid} ? $$state{wolfram_appid} : "");
return reply("the bot owner should configure the Wolfram API ID first.") if $wolfram_app_id eq "";

my $args = $$irc_event{args};

my $url = "http://api.wolframalpha.com/v2/query?appid=$wolfram_app_id&input=".uri_escape($args);
my $content = fetchURL($url);
return reply("the query to Wolfram failed.") if not defined $content;

my $query_input = my $query_decapprox = my $query_result = "";

my $xp = XML::XPath->new(xml => $content);
my $nodeset = $xp->find("//pod[\@id='Input']/subpod/plaintext/text()");
my ($node) = $nodeset->get_nodelist;
if (defined $node) { $query_input = XML::XPath::XMLParser::as_string($node); }

my $nodeset = $xp->find("//pod[\@id='Result']/subpod/plaintext/text()");
my ($node) = $nodeset->get_nodelist;
if (defined $node) { $query_result = XML::XPath::XMLParser::as_string($node); }

if ( ($query_input =~ m/^\s*$/) or ($query_result =~ m/^\s*$/) ) {
    return reply("query not understood.");
} else {
    return reply($query_input . " = " . $query_result);
}

return;


#
#
#
#


sub fetchURL {
    my ($url) = @_;
    my $lwp = LWP::UserAgent->new;
    $lwp->max_redirect(7);
    $lwp->requests_redirectable(['GET', 'HEAD']);
    $lwp->timeout(15);
    $lwp->agent('Mozilla/5.0 (Windows NT 6.0; rv:28.0) Gecko/20100101 Firefox/28.0');
    my $req = HTTP::Request->new(GET => $url);
    my $res = $lwp->request($req);
    if (!$res->is_success) {
        msg("GET failed on '$url'");
        msg("---- " . $res->status_line);
        public("wolfram: " . $res->status_line);
        return undef;
    } else {
        return $res->content;
    }
}
