#!/bin/perl

use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Parallel::ForkManager;
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Alias;
use JSON ;
use Data::Dumper;
use Log::Minimal;
use Net::GrowthForecast;

my $timeout = 3;
my ($host,$mbean,$attr,$check_value,$jolokia_port);
my ($gf_host,$gf_port,$graph_exe,$graph_service_name);
my %graph_mode = ("mode" => "count");

GetOptions(
    "m=s" => \$mbean,
    "a=s" => \$attr,
    "c=s" => \$check_value,
    "port=s" => \$jolokia_port,
    "host=s" => \$host,
    "gh=s" => \$gf_host,
    "gp=s" => \$gf_port,
    "graph_service_name=s" => \$graph_service_name,
    "exe=s" => \$graph_exe,
);

infof("$gf_host,$gf_port,$graph_exe");

sub print_help{
    print "Option does not exist\n";
    print "perl ./jmx_to_gf.pl -m oracle.ucp.admin.UniversalConnectionPoolMBean:name" ;
    print " -a UniversalConnectionPoolManager* -c borrowedConnectionsCount -h 127.0.0.1 -p 8080";
    print "-graph  -g 127.0.0.1 ";
    exit 1;
}


sub get_jmx_value{
    my $host = $_[0];
    my $jolokia_port = $_[1];
    my $mbean = $_[2];
    my $attr = $_[3];
    my $check_value = $_[4];
    my @all_status;

    my $mbean_attr = "$mbean" . "=" . "$attr";
    my $jmx_value;
    eval {
        $SIG{ALRM} = sub { die "CHECK NODE IS timeout $host\n ";};
        alarm($timeout);
        my $agent = new JMX::Jmx4Perl(mode=>"agent", url => "http://$host:$jolokia_port/jolokia");
        $jmx_value = $agent->get_attribute("$mbean_attr","$check_value");
        infof("get jmx value is $jmx_value");
        print Dumper($jmx_value);
        alarm 0;
    };
    if ($@) {
        alarm 0;
        critf("$@");
    }

    return $jmx_value;
}

sub gf_post_data{
    my $gf_host = $_[0];
    my $gf_port = $_[1];
    my $graph_service_name = $_[2];
    my $graph_host_name = $_[3];
    my $graph_name = $_[4];
    my $post_value = $_[5];

    eval{
        my $gf = Net::GrowthForecast->new( host => $gf_host , port => $gf_port );

        $gf->post( "$graph_service_name", "$graph_host_name", "$graph_name", $post_value, %graph_mode );
        infof("POST OK :$graph_service_name $graph_host_name $graph_name $post_value");
    };if($@){
        critf("$@");
        return 1;
    }
    return 0;
}


my $jmx_value = get_jmx_value($host,$jolokia_port,$mbean,$attr,$check_value);
infof("result is $jmx_value");

my %jmx_hash = %$jmx_value;
foreach my $key(keys(%jmx_hash)){
    my $jmx_value_ref = $jmx_hash{$key};
    my %jmx_value_hash = %$jmx_value_ref;
    infof("$key : $check_value : $jmx_value_hash{$check_value}");
    if ($graph_exe eq "on"){
        infof("graph execute!!");
        gf_post_data($gf_host,$gf_port,$graph_service_name,$host,$check_value,$jmx_value_hash{$check_value});
    }
}

