
use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Data::Dumper;
use JSON;
use Log::Minimal;
use LWP::Simple;

my ($threshold,$limit,$error_rate,$url);

GetOptions(
    "t=i" => \$threshold,
    "l=i" => \$limit,
    "e=i" => \$error_rate,
    "h=s" => \$url
);

$url = $url . $limit;

my $ua;
my $response;
my $cluster_result_json;
my $cluster_latency;
my $cluster_error_rate;

eval{
    $ua = LWP::UserAgent->new;
    $response = $ua->get($url);


    if ($response->is_success) {
        $cluster_result_json = $response->content;
    } else {
        die $response->status_line;
    }
};if($@){
    print "get NG!!$@";
    exit 2;
}
my $cluster_result_ref = decode_json($cluster_result_json); 
foreach my $item (@$cluster_result_ref) {
    $cluster_latency = $item->{latency};
    $cluster_error_rate = $item->{errorRate};
}

print "Latency:$cluster_latency > Thresohold:$threshold ErrorRate:$error_rate ";
if ( $cluster_latency > $threshold or $cluster_error_rate > $error_rate ){
    print "status NG!!";
    exit 2;
}
print "status OK!!";
exit 0;
