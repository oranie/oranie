#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Parallel::ForkManager;
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Alias;
use Net::GrowthForecast;
use Log::Minimal;

local $Log::Minimal::LOG_LEVEL = "INFO";

my @host_list;
my $master_host;
my $timeout = 10;
my $jolokia_port = 8778;
my %mbean_attr_hash = (
    "LiveDiskSpaceUsed" => "org.apache.cassandra.db:type=ColumnFamilies,"
);

my $regexp_word = ".*";
my $node_ip_range = "192.168";

my $gf_host = "127.0.0.1";
my $gf_port = "5125";
my $gf_execute = "off";

my $concurrent_process = 30;
my $pm = Parallel::ForkManager->new($concurrent_process);


GetOptions(
    "g=s" => \$gf_execute,
    "m=s" => \$master_host,
    "r=s" => \$regexp_word,
    "i=s" => \$node_ip_range
);

sub get_cassandra_host_list{
    my $master_host = $_[0];

    $SIG{ALRM} = sub { print "CHECK MASTER NODE IS timeout $master_host\n ";my @cassandra_server_status_list = "time out error";exit 1; };
    alarm($timeout);
    my $cmd = "/usr/local/cassandra/bin/nodetool -h $master_host ring | grep '$node_ip_range' | awk '{print \$1}'";
    infof($cmd);
    my @host_list = qx{$cmd};
    if  ( $? != 0 ){
        alarm 0;
        $host_list[0] = "NG";
        return 1;
    }
    alarm 0;

    return @host_list;
}

sub ks_and_cflist_get{
    my $master_host = $_[0];
    chomp($master_host);

    $SIG{ALRM} = sub { print "CHECK MASTER NODE IS timeout $master_host\n ";my @cassandra_server_status_list = "time out error";exit 1; };
    alarm($timeout);
    my $cmd = "/usr/local/cassandra/bin/nodetool -h $master_host cfstats | egrep 'Column Family|Keyspace' | sed -e 's/\t\t//g'";
    infof($cmd);
    my @ks_and_cflist = qx{$cmd};
    if  ( $? != 0 ){
        alarm 0;
        $ks_and_cflist[0] = "NG";
        return 1;
    }
    alarm 0;

    return @ks_and_cflist;
}

sub line_regexp{
    my $regexp_line = $_[0];
    chomp($regexp_line);
    $regexp_line =~ s/.*: //;

    return $regexp_line;
}

sub make_ks_and_cf_kv{
    my @ks_and_cflist = @_;
    my $ks_name;
    my $cf_name;
    my %all_list_hash;

    foreach my $line (@ks_and_cflist){
        if ($line =~ /Keyspace/) {
            $ks_name = line_regexp($line);
            next;
        }
        $cf_name = line_regexp($line);
        $all_list_hash{"$cf_name"} = "$ks_name";
    } 
    return %all_list_hash;
}

sub gf_post_data{
    my $host = $_[0];
    my $graph_name = $_[1];
    my $result = $_[2];

    eval{
        my $gf = Net::GrowthForecast->new( host => $gf_host , port => $gf_port );
        $gf->post( 'cassandra', "$host", "$graph_name", $result );
    };if($@){
        critf("$@\n");
        return 1;
    }
    return 0;
}

sub get_cf_diskspace{
    my $host = $_[0];
    my $cf_name = $_[1];
    my $ks_name = $_[2];

    my %status_hash;
    my @all_status;
 
    while (my ($attr, $mbean_base) = each(%mbean_attr_hash)){
        my $mbean = "${mbean_base}keyspace=$ks_name,columnfamily=$cf_name";
        my $url = "http://$host:$jolokia_port/jolokia/read/$mbean/$attr";
        my $live_space;
        eval {
            $SIG{ALRM} = sub { die "CHECK NODE IS timeout $host\n ";};
            alarm($timeout);
            my $agent = new JMX::Jmx4Perl(mode=>"agent", url => "http://$host:$jolokia_port/jolokia");
            
            my $result = $agent->get_attribute("$mbean","$attr");
            my @status= ("$host","$ks_name","$cf_name","$attr","$result");
            my $graph_name = "$ks_name"."_"."$cf_name"."_"."$attr";

            if ($gf_execute eq "on"){
                infof(" execute post data ($host, $graph_name, $result)");
                gf_post_data($host, $graph_name, $result);
            }else{
                infof("if (-g on) will post data ($host, $graph_name, $result)");
            }
            
            push(@all_status,\@status);
            alarm 0;
        };
        if ($@) {
            alarm 0;
            critf("$@");
            push(@all_status,$@);
            last;
        }
    }
    return @all_status;
}

sub ks_cflist_to_graph{
    my $host = $_[0];
    my $all_list_hash_ref = $_[1];
    my %all_list_hash = %$all_list_hash_ref ;

    eval{
        foreach my $cf_name ( keys( %all_list_hash ) ) {
            my $ks_name = $all_list_hash{$cf_name};
            infof("$ks_name =~ $regexp_word");
            if ($ks_name =~ "$regexp_word"){
                my @host_status = get_cf_diskspace($host,$cf_name,$ks_name);
                sleep 1;
            }
        }
    };if($@){
        critf("$@");
        return 1;
    }

    return 0 ;
}

eval{
    infof("ALL EXECUTE START!!! master host is $master_host");
    @host_list = get_cassandra_host_list($master_host);
    infof("host list is @host_list");
    my @ks_and_cf_list = ks_and_cflist_get($host_list[0]);
    foreach my $host(@host_list){
        $pm->start and next;
        chomp($host);
        my %all_list_hash = make_ks_and_cf_kv(@ks_and_cf_list);
        ks_cflist_to_graph($host,\%all_list_hash);
        $pm->finish;
    }
    $pm->wait_all_children;
};if($@){
    critf("$@");
}
infof("ALL EXECUTE OK!!!");

