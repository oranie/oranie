#!/usr/bin/perl
# Timeout is 10sec
# 監視ホストからランダムにチェックするノードを選択し、そのノードから情報を取得して各ノードを監視します
#######################################################################################################
use strict;
use warnings;
 
 
my @host_list = @ARGV;
my $host_count = @host_list;
my @ng_host_list;
my $rand_host = @host_list[(rand $host_count)];
my $master_node = $rand_host;
 
 
$SIG{ALRM} = sub { print "CHECK MASTER NODE IS timeout $master_node\n ";exit 1; };
alarm 10;
my @cassandra_server_status_list = qx{/usr/local/cassandra/bin/nodetool -h $master_node ring | grep "Up"};
alarm 0;
 
if ( $? != "0" ){
    print "CHECK MASTER NODE IS DOWN !!! $master_node \n";
    exit 1;
}else{
    print "CHECK MASTER NODE IS OK! $master_node \n";
};
 
 
foreach my $host (@host_list){
    my $status = grep /$host / ,@cassandra_server_status_list;
    if ($status == "0"){
        push(@ng_host_list,$host);
    }else{
        print "$host is OK!!\n";
    }
}
 
if ( scalar(@ng_host_list) != "0" ){
   foreach my $ng_host (@ng_host_list){
       print "$ng_host is down!!\n";
   }
   exit 1;
}
 
exit 0;

