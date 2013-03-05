#!/usr/bin/perl
# === tomcat_threads_threshold.pl ===
#
# -*- perl -*-

=head1 NAME

tomcat_threads_threshold - The script to monitor the number of tomcat-threads for 'mon'
running on the machine, and (in addition to a simple process count),
separate then into "busy" or "idle" servers.

=head1 CONFIGURATION

Configurable variables

 timeout   - Connection timeout
 url       - Override default status-url
 ports     - HTTP port numbers
 user      - Manager username
 password  - Manager password
 connector - Connector to query, defaults to "http-".$PORT

=head1 USAGE

Requirements: Needs access to
http://<user>:<password>@localhost:8080/manager/status?XML=true (or
modify the address for another host). 

Tomcat 5.0 or higher.

A munin-user in $CATALINA_HOME/conf/tomcat-users.xml should be set up
for this to work.

Tip: To see if it's already set up correctly, just run this plugin
with the parameter "autoconf". If you get a "yes", everything should
work like a charm already.

tomcat-users.xml example:
    <user username="munin" password="<set this>" roles="standard,manager"/>

=head1 AUTHOR

Rune Nordb?e Skillingstad <runesk@linpro.no> (original version)
Kazuhiro Oinuma <oinume@gmail.com> (no XML::Simple version)
Kenichi Masuda <masuken@gmail.com> (Customized for mon monitor script)

=head1 LICENSE

Unknown license

=head1 MAGIC MARKERS

 #%# family=manual
 #%# capabilities=autoconf

=cut

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
my $ret = undef;

if (!eval "require LWP::UserAgent;") {
    $ret = "LWP::UserAgent not found";
}

my @ARG = ();
my @failed_servers = ();
my @down_servers_list = ();
my @threshold = ();
my @servers = ();
my $URL       = exists $ENV{'url'}       ? $ENV{'url'}         : "http://%s:%s\@%s:%d/manager/status?XML=true";
my $PORT      = exists $ENV{'ports'}     ? $ENV{'ports'}       : 8080;
my $USER      = exists $ENV{'user'}      ? $ENV{'user'}        : "default_user_name";
my $PASSWORD  = exists $ENV{'password'}  ? $ENV{'password'}    : "default_user_pass";
my $TIMEOUT   = exists $ENV{'timeout'}   ? $ENV{'timeout'}     : 30;
my $CONNECTOR = exists $ENV{'connector'} ? $ENV{'connector'}   : "http-" . $PORT;
GetOptions(
    "thread-threshold|t=s" => \@threshold
);
my $THRESHOLD = exists $threshold[0]     ? $threshold[0]       : 30;

# main
foreach my $ipaddr (@ARGV)
{
    my $url = _create_req_url_string($USER, $PASSWORD, $ipaddr, $PORT);
#print $url;
    my $content = _get_response_body($url);
#print $content;    
    my %connectors = ();
    my $current_connector = undef;
    while ($content =~ m!<([\w-]+)\s*(.*?)/?>!igs) {
        my $element = strip($1);
        my $attributes_str = strip($2);
    
        my %attributes = ();
        for my $attr (split ' ', $attributes_str) {
            my ($key, $value) = split '=', $attr;
            $key = strip($key);
            $value = strip($value);
            if ($value =~ /^['"](.+)['"]$/) { # remove quote
                $value = $1;
                $attributes{$key} = $value;
            }
        }
    
        if ($element eq 'connector') {
            $current_connector = $attributes{name};
        }
        if ($element eq 'threadInfo') {
            # save threadInfo attributes
            $connectors{$current_connector} = \%attributes;
        }
    }


    print "$ipaddr: ";
    my $thread_info = $connectors{$CONNECTOR};
    my $idle_thread_cnt = $thread_info->{currentThreadCount} - $thread_info->{currentThreadsBusy};
    my $busy_thread_cnt = $thread_info->{currentThreadsBusy};
    my $max_thread_cnt  = $thread_info->{maxThreads};
    print(sprintf("[ busy.value: %d, ", $busy_thread_cnt));
    print(sprintf(
        "idle.value: %d, ", $idle_thread_cnt
    ));
    print(sprintf("max.value: %d ]\n", $max_thread_cnt), "\n");

    @failed_servers = _detect_failed_server($ipaddr, $busy_thread_cnt, $max_thread_cnt, $THRESHOLD);
}

#print scalar(@failed_servers);
if ( $failed_servers[0] )
{
    print "\n==========";
    print "\n Check Below Servers";
    print "\n==========\n";
    #print Dumper @failed_servers;
    print  join("\n",@failed_servers);
    print "\n----------\n";
    exit(1);
}



sub strip {
    my $str = shift;
    unless (defined $str) {
        return undef;
    }

    $str =~ s/^\s+//s;
    $str =~ s/\s+$//s;
    return $str;
}


sub _create_req_url_string
{
    my ($_user, $_password, $_ipaddr, $_port) = @_;
    my $req_url = sprintf $URL, $_user, $_password, $_ipaddr, $_port;
    return $req_url;
}


sub _get_response_body
{
    my ($_url) = @_;
    my $ua = LWP::UserAgent->new(timeout => $TIMEOUT);
    my $response = $ua->request(HTTP::Request->new('GET',$_url));
    my $content = $response->content;
    my $res_code = $response->code;
    my $res_message = $response->message;
    if ( $res_code != 200 )
    {
        print "response_code: $res_code";
        print "\nresponse_message: $res_message\n";
        exit(1);
    }
#print Dumper $response;

    return $content;
}


sub _detect_failed_server
{
    my ($_ipaddr, $_busy_thread, $_max_thread, $_threshold) = @_;

    my $_down_flg = _threshold_detector($_busy_thread, $_max_thread, $_threshold); 
    if ( $_down_flg == 1 )
    {
        push(@down_servers_list,$_ipaddr);
        return @down_servers_list;
    }
}


sub _threshold_detector
{
    my ($_busy_thread, $_max_thread, $_threshold) = @_;
    if( $_busy_thread/$_max_thread*100 > $_threshold )
    {
#print "\n\nerror detect\n\n";
        return 1;
    }
}
# vim:syntax=perl

