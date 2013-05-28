#!/usr/bin/perl
# ノードからtpstats情報を取得して、pending値が閾値を超えていないか監視します
#######################################################################################################
use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Parallel::ForkManager;

my @host_list;
my $host_count = @host_list;
my @ng_host_list;
my $threshold;
my $timeout = 10;
my $concurrent_process = 5;
GetOptions(
    "t=i" => \$threshold,
    "h=s{,}" => \@host_list
);

sub pending_status_get{
    my $host = $_[0];

    $SIG{ALRM} = sub { print "CHECK MASTER NODE IS timeout $host\n ";my @cassandra_server_status_list = "time out error";exit 1; };
    alarm($timeout);
    my @cassandra_server_status_list = qx{/usr/local/cassandra/bin/nodetool -h $host tpstats | grep "Stage"};
    if  ( $? != 0 ){
        alarm 0;
        $cassandra_server_status_list[0] = "NG";
        return 1;
    }
    alarm 0;

    return @cassandra_server_status_list;
}

sub pending_status_check{
    my @server_status_list = @_;
    my @ng_status_list;

    foreach my $status (@server_status_list){
        chomp($status);
        my @check_list = split(/ +/, $status);
        my $pending_score = $check_list[2];
        if ( $threshold < $pending_score){
            print "$pending_score is NG!!!\n";
            print "$status is $pending_score < $threshold (threshold) \n";
            push(@ng_status_list,$status);
        }else{
            #print "$status is $pending_score < $threshold (threshold) \n";
        }
    }
    return @ng_status_list;
}

my $pm = Parallel::ForkManager->new($concurrent_process);
$pm->run_on_finish(sub {
    my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
    my $host = $data->{'host'};
    my $server_status_list_ref = $data->{'server_status_list'};
    my $ng_status_list_ref = $data->{'ng_status_list'};

    my @server_status_list = @$server_status_list_ref;
    my @ng_status_list = @$ng_status_list_ref;

    my $status = scalar(@ng_status_list);
    if ( $status != 0 ){
        print "$host is NG pending score is @ng_status_list\n";
        push(@ng_host_list,$host);
    }else{
        print "$host is OK!!\n";
    }

});

foreach my $host (@host_list){
    $pm->start and next;
        my @server_status_list ;
        my @ng_status_list ;

        @server_status_list = pending_status_get($host);
        if ( $? == 0 ){
            @ng_status_list = pending_status_check(@server_status_list);
        }else{
            $ng_status_list[0] = "nodetool erxecute NG\n";
        }
    $pm->finish(0, { 'host' => $host, 'server_status_list' => \@server_status_list, 'ng_status_list' => \@ng_status_list});
}
$pm->wait_all_children;
 
if ( scalar(@ng_host_list) != 0 ){
   foreach my $ng_host ( @ng_host_list ){
       print "RESULT : $ng_host is pending score over!! or nodetool execute NG\n";
   }
   exit 1;
}
 
exit 0;

