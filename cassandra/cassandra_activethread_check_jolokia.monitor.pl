#!/bin/perl

use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Parallel::ForkManager;
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Alias;
use JSON ;
use Data::Dumper;

my $check_value = "PendingTasks";
my $check_active_thread = "ActiveCount";
my $check_max_thread = "CorePoolSize";
my $active_count_per_threshold = "0.9";
my $jolokia_port = "8778";
my $threshold = 0;
my $ng_flag = 0;
my @host_list; 
my $timeout = 3;
my $concurrent_process = 30;
my @ng_host_list;

GetOptions(
    "t=i" => \$threshold,
    "p=s" => \$active_count_per_threshold,
    "h=s{1,}" => \@host_list
);

if ( scalar($threshold) == 0 ){
    print "Option does not exist\n";
    print "cassandra_pending_jolokia.monitor -t [threshold count ] -h [host list example;10.0.0.1 10.0.0.2]\n";
    exit 1;
}

if ( scalar($active_count_per_threshold) == 0 ){
    print "Option does not exist\n";
    print "cassandra_pending_jolokia.monitor -t [threshold count(example:100)] -p [active count percentage(example:0.1)] -h [host list example;10.0.0.1 10.0.0.2]\n";
    exit 1;
}

if ( scalar(@host_list) == 0 ){
    exit 0;
}

my %mbean_attr_hash = (
    "ReadStage"=>"org.apache.cassandra.request:type",
    "MutationStage"=>"org.apache.cassandra.request:type",
    "ReplicateOnWriteStage"=>"org.apache.cassandra.request:type"
);

sub check_active_thread{
    my $active_thread = $_[0];
    my $max_thread = $_[1];

    my $result = $active_thread / $max_thread;
    return $result;
}

sub get_jmx_value{
    my $host = $_[0];
    my $jolokia_port = $_[1];
    my $threshold = $_[2];
    my @all_status;
 
    while (my ($attr, $mbean) = each(%mbean_attr_hash)){
        my $mbean_attr = "$mbean" . "=" . "$attr";
        my $pending_task;
        my $active_thread;
        my $max_thread;
        my $active_thread_per;
        eval {
            $SIG{ALRM} = sub { die "CHECK NODE IS timeout $host\n ";};
            alarm($timeout);
            my $agent = new JMX::Jmx4Perl(mode=>"agent", url => "http://$host:$jolokia_port/jolokia");
            $pending_task = $agent->get_attribute("$mbean_attr","$check_value");
            $active_thread = $agent->get_attribute("$mbean_attr","$check_active_thread");
            $max_thread = $agent->get_attribute("$mbean_attr","$check_max_thread");
            #print "$pending_task $active_thread $max_thread \n";
            alarm 0;
        };
        if ($@) {
            alarm 0;
            warn $@;
            push(@all_status,$@);
            last;
        }
        $active_thread_per = check_active_thread($active_thread,$max_thread);

        if ($pending_task > $threshold or $active_thread_per > $active_count_per_threshold){
            my $status = "$host $attr pending threshold over!!PendingTask is $threshold->$pending_task and Thread status is $active_thread>$max_thread";
            print "$status\n";
            print "act_thread_per is $active_thread_per > threshold is $active_count_per_threshold\n";
            push(@all_status,$status);
        }
    }
    return @all_status;
}

my $pm = Parallel::ForkManager->new($concurrent_process);
$pm->run_on_finish(sub {
    my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
    my $host = $data->{'host'};
    my $all_status_ref = $data->{'all_status'};

    my @all_status_list = @$all_status_ref;

    if ( scalar(@all_status_list) != 0 ){
        $ng_flag = 1;
        push(@ng_host_list,$host);
    }
    return $host;
});

foreach my $host(@host_list){
    $pm->start and next;
    my @all_status = get_jmx_value($host,$jolokia_port,$threshold);
    $pm->finish(0, { 'host' => $host, 'all_status' => \@all_status});
}
$pm->wait_all_children;

if (scalar(@ng_host_list) != 0 ){
    $ng_flag = 1;
}

if ($ng_flag != 0){
    print "Pending check is NG\n";
    exit 1;
}
print "ALL SERVER OK";
exit 0;
