#!/usr/bin/perl
#このmonitorはjmxquery.jarを利用してmbeansをチェックします。その為、jmxquery.jarの仕様に則った形でコマンドを生成してチェックします。
##http://www.op5.com/how-to/jboss-monitoring/
##Usage: check_jmx -U url -O object_name -A attribute [-K compound_key] [-I attribute_info] [-J attribute_info_key] [-u username] [-p password] -w warn_limit -c crit_limit [-v[vvv]] [-help]
##
##example:
##/usr/local/java/bin/java -cp /tmp/jmxquery.jar org.nagios.JMXQuery -U service:jmx:rmi:///jndi/rmi://192.168.0.1:10001/jmxrmi -O org.apache.flume.channel:type=ch1 -A StopTime -w 90 -c 100 -vvv
##実行結果：JMX OK StopTime=0
##
##使用例
##perl ./oranie_test.pl -b org.apache.flume.source:type=scribe org.apache.flume.channel:type=ch1 org.apache.flume.sink:type=avro1 org.apache.flume.sink:type=avro2 org.apache.flume.sink:type=avro3 -p 10001 -t 1 -a StopTime -h 192.168.0.1
##monで使う時は最後の引数にホストIPを渡されるので、-hオプションを最後に書くこと


use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
 
my $mon_dir = "/usr/local/mon/mon.d";
my $java = "/usr/local/java/bin/java";
my $jar = "/tmp/jmxquery.jar";

my @host_list;
my @mbeans_list;
my $host_count = @host_list;
my @ng_host_list;
my $attributes;
my $port;
my $threshold;
my $timeout = 1;
my $percalc = 0;
my $HELP;

GetOptions(
    "t=i" => \$threshold,
    "p=i" => \$port,
    "a=s" => \$attributes,
    "percalc" => \$percalc,
    "b=s{1,}" => \@mbeans_list,
    "h=s{1,}" => \@host_list,
    'help' => \$HELP
) || die("GetOptions failed") ;

if ( $HELP ) {
    die "this monitor usage : { monitor -b [jmx mbeans] -a [jmx attributes] -p [port] -t [threshold] -h [host_ip]}"
}


#オプションに設定された情報を利用して指定されたmbeansの値を取得、チェックします。
#但し二つの値を取得してその割合を計算する場合を考慮して、ここではチェックしたステータスを戻り値に入れるだけでmonitor全体の判定はしません。
#閾値を中で二つ作っているのは、warnigsとcritical用の値を同じ値で設定出来ないので、0を入れられた時の為に2倍にしたあと+1しています。
sub pending_status_get{
    my $host = $_[0];
    my $mbeans = $_[1];
    my $attributes = $_[2];
    my $threshold = $_[3];
    my $timeout = $_[4];
    my $threshold2 = ($threshold * 2) + 1;
    my $status_result; 
    my $retval = $?;

    eval {
        $SIG{ALRM} = sub { die $status_result = "Status=TimeOutError";};
        alarm $timeout;
        my $cmd = "$java -cp $jar org.nagios.JMXQuery -U service:jmx:rmi:///jndi/rmi://$host:$port/jmxrmi -O $mbeans -A $attributes -w $threshold -c $threshold2 ";
        #print $cmd . "\n";
        $status_result = qx{$cmd} or die ;
        $retval = $?;
        if ( $retval != 0 ){
            alarm 0;
        }
        alarm 0;
    };if ($@) {
        $retval = 1;
    }
    chomp($status_result);
    print "server status is $host,$mbeans,$status_result,$retval\n";
    my @host_status_list = ($host,$mbeans,$status_result,$retval);
    return @host_status_list;
}

#サブルーチン実行して、対象hostのステータスを取得する。
#対象ホストのステータスをチェックして0以外の戻り値を返している箇所があればNGフラグを立てる
my %all_host_all_status_hash;
my $ng_flag = 0;

foreach my $host (@host_list){
    my @host_all_status_list;
    foreach my $mbeans (@mbeans_list){
        my @host_status_list = pending_status_get($host,$mbeans,$attributes,$threshold,$timeout);
    	if ( $host_status_list[3] != 0){
            $ng_flag = 1;
        }
	#push(@all_host_status_list,\@host_status_list);
	    push(@host_all_status_list,\@host_status_list);
    }
	@{$all_host_all_status_hash{"$host"}} = \@host_all_status_list;
    
}

#$percalcがONの場合,同一ホスト内で取得したmbeansの値で割合を計算して、閾値以上かどうか確認します。
#閾値以上、値が不正などどれか一つでも引っかかったらpercalc_ng_flagフラグをONにします
my $percalc_ng_flag = 0;
if ( $percalc == 1){
   $ng_flag = 0;
    while (my ($host, $host_all_status_list_ref) = each(%all_host_all_status_hash)) {
        my @per_list;
        foreach my $host_all_status_list (@{$host_all_status_list_ref}) {
            foreach my $list (@$host_all_status_list){
                my @host_status_list = @$list;
                my $result_val = $host_status_list[2];
                my ($key, $val) = split /=/, $result_val, 2; 
                push(@per_list,$val);
            }
        }
        if ($per_list[0] eq "TimeOutError" or $per_list[1] eq "TimeOutError"){
            print "$per_list[0] or $per_list[1] is TimeOutError. skip,,,,\n";
            $percalc_ng_flag = 1;
        }elsif ($per_list[0] == 0 or $per_list[1] == 0 ){
            print "$per_list[0] or $per_list[1] is 0 . skip,,,,\n";
            $percalc_ng_flag = 1;
        } else {
            my $calc_result = ($per_list[0] / $per_list[1]) * 100;
            print "$host $per_list[0] / $per_list[1] is $calc_result . $threshold over check\n";
            if ($calc_result >= $threshold){
                print "$calc_result >= $threshold  NG!!!!\n";
                $percalc_ng_flag = 1;
            }
        }   
    }
}

#NGフラグを確認して、立っていれば戻り値を１で終了
if ( $ng_flag == 1 or $percalc_ng_flag == 1){
    print "Server Status is NG!!!\n";
    exit 1;
}

print "Server Status is ALL OK!!!\n";
exit 0;

