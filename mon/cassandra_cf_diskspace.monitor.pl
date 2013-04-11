#!/usr/bin/perl
# ノードからcfstats情報を取得して、生成したkeyspace(ks)とcolumn family(cf)のリストを生成し、
# その情報を元にjolokiaを叩いて各cfのDisk使用量を取得します
#######################################################################################################
use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Parallel::ForkManager;
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Alias;
use JSON ;
use Data::Dumper;
use Net::GrowthForecast;

my @host_list;
my $master_host;
my $timeout = 10;
my $jolokia_port = 8778;
my %mbean_attr_hash =(
    "LiveDiskSpaceUsed" => "org.apache.cassandra.db:type=ColumnFamilies,",
#    "TotalDiskSpaceUsed" => "org.apache.cassandra.db:type=ColumnFamilies,"
);

my $gf_host = "10.174.0.68";
my $gf_port = "5125";
my $gf_execute = "off";

my $concurrent_process = 30;
my $pm = Parallel::ForkManager->new($concurrent_process);


GetOptions(
    "g=s" => \$gf_execute,
    "m=s" => \$master_host
);

sub get_cassandra_host_list{
    my $master_host = $_[0];

    $SIG{ALRM} = sub { print "CHECK MASTER NODE IS timeout $master_host\n ";my @cassandra_server_status_list = "time out error";exit 1; };
    alarm($timeout);
    my $cmd = "/usr/local/cassandra/bin/nodetool -h $master_host ring |grep '10.17'| awk '{print \$1}'";
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
    my $host = $_[0];
    chomp($host);

    $SIG{ALRM} = sub { print "CHECK MASTER NODE IS timeout $host\n ";my @cassandra_server_status_list = "time out error";exit 1; };
    alarm($timeout);
    my $cmd = "/usr/local/cassandra/bin/nodetool -h ${host} cfstats | egrep 'Column Family|Keyspace' | sed -e 's/\t\t//g'";
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
        print "$@\n";
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
        #print "url is $url\n";
        my $live_space;
        eval {
            $SIG{ALRM} = sub { die "CHECK NODE IS timeout $host\n ";};
            alarm($timeout);
            my $agent = new JMX::Jmx4Perl(mode=>"agent", url => "http://$host:$jolokia_port/jolokia");
            
            my $result = $agent->get_attribute("$mbean","$attr");
            my @status= ("$host","$ks_name","$cf_name","$attr","$result");
            my $graph_name = "$ks_name"."_"."$cf_name"."_"."$attr";
            if ($gf_execute eq "on"){
                gf_post_data($host, $graph_name, $result);
            }else{
                print "if execute post data is ($host, $graph_name, $result)\n";
            }
            
            push(@all_status,\@status);
            alarm 0;
        };
        if ($@) {
            alarm 0;
            warn $@;
            push(@all_status,$@);
            last;
        }
        #exit;
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
            if ($ks_name =~ "amebame"){
                my @host_status = get_cf_diskspace($host,$cf_name,$ks_name);
            }
        }
    };if($@){
        print "$@";
        return 1;
    }
    return 0 ;
}

eval{
    @host_list = get_cassandra_host_list($master_host);
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
    print "$@\n";
}

