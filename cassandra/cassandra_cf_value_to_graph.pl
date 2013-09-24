
use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Parallel::ForkManager;
use Data::Dumper;
use JSON;
use Net::GrowthForecast;
use Log::Minimal;

local $Log::Minimal::LOG_LEVEL = "WARN";

my $gf_host = "10.174.0.93";
my $gf_port = "5125";
my $gf_execute = "off";
my $graph_service_base_name = "cassandra_cfstats_";

my $master_host ;
my @graph_item_list;

GetOptions(
    "h=s{1}" => \$master_host,
    "m=s{1,}" => \@graph_item_list,
) ;

my $nodetool = "/usr/local/cassandra/bin/nodetool";
my @node_list = qx/$nodetool -h $master_host ring| grep datacenter1 | awk '{print \$1}'/;

my $timeout = 15;

sub cfstats_json_get{
    my $host = $_[0];
    chomp($host);

    $SIG{ALRM} = sub { print "CHECK HOST IS timeout $host\n ";};
    alarm($timeout);
    my $cmd = "/usr/local/cassandra/bin/nodetool -h $host cfstats | ruby /home/growthforecast/repo/cfstats2json.rb";
    my $cfstats_json = qx{$cmd};
    if  ( $? != 0 ){
        alarm 0;
        $cfstats_json = "NG";
        return 1;
    }
    alarm 0;

    return $cfstats_json;
}

sub latency_calc{	
	my $latency_value = $_[0];
	my @latency = split(/ /,$latency_value);
    my $calc = int($latency[0]);
	return $calc;
}

sub gf_post_data{
    my $host = $_[0];
    my $graph_service_name = $_[1];
    my $graph_section_name = $_[2];
    my $graph_title_name = $_[3];
    my $value = $_[4];

    eval{
        my %graph_mode;
        if ($graph_section_name =~ /Count/ ){
           %graph_mode = ("mode" => "derive");
        }else{
           %graph_mode = ("mode" => "gauge");
        }
        my $gf = Net::GrowthForecast->new( host => $gf_host , port => $gf_port );
        $gf->post( "$graph_service_name", "$graph_section_name", "$graph_title_name", $value, %graph_mode );
        infof("service_name:$graph_service_name , section_name:$graph_section_name , title_name:$graph_title_name , value:$value , %graph_mode");
    };if($@){
        critf("growthforecast POST NG!! $@\n");
        return 1;
    }
    return 0;
}

sub execute_graph{
    my $host = $_[0];
    my $graph_item = $_[1];
    eval{
        my $cfstats_json = cfstats_json_get($host);
        my $cfstats = decode_json($cfstats_json);
        my %cfstats_hash = %$cfstats;
        my @keyspace_list;
        my @key_cf_list;
        my @value_list;
    
        foreach my $key (keys(%cfstats_hash)){
    	    push(@keyspace_list,$key);
        }
    
        foreach my $key (@keyspace_list){
    	    my $cf_ref = $cfstats_hash{$key}{'cf'};
            my %cf_hash = %$cf_ref;
            foreach my $cf_key (keys(%cf_hash)){
                my $cf_value_ref = $cfstats_hash{$key}{'cf'}{$cf_key};
                my %cf_value_hash = %$cf_value_ref;
                my $value = $cfstats_hash{$key}{'cf'}{$cf_key}{$graph_item};
                $value =~ s/NaN/0/;
                infof("$host,$cf_key,$graph_item,$value");
                push(@value_list,$value);
            }
        }
        my $total = 0;
        foreach my $value (@value_list){
            $total = $total + $value;
        }

        my $graph_name = $graph_item;
        $graph_name =~ s/ +//g;
        my $graph_service_name = "cassandra_node_total";
        my $graph_section_name = $graph_name;
        my $graph_title_name = $host;
        gf_post_data($host,$graph_service_name,$graph_section_name,$graph_title_name,$total);
        infof("$host $graph_service_name $graph_section_name $graph_title_name total is $total");
    };if($@){
        critf("cassandra cfstats POST NG!!! $@\n");
        exit 1;
    }
}

eval{
    my $pm = Parallel::ForkManager->new(5);
    foreach my $host (@node_list){    
        $pm->start and next;
        chomp($host);
        infof("$host POST EXECUTE START");
        foreach my $graph_item(@graph_item_list){
            execute_graph($host,$graph_item);
        }
        $pm->finish;
    }
    $pm->wait_all_children;
};if($@){
    critf("cassandra cfstats POST NG!!! $@\n");
}

