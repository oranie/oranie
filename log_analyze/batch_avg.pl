#!/usr/bin/perl

use strict;
use warnings;
use DBD::mysql;
use DBI;
use Config::Simple;
use Parallel::ForkManager;


my $cfgObj = new Config::Simple;
$cfgObj->read('./lib/config.pm');
my $cfg = $cfgObj->vars();
my $d = $cfg->{'database.db'};
my $u = $cfg->{'database.user'};
my $p = $cfg->{'database.password'};

#並列実行をとりあえず11で(3回回せば確実に1ヶ月分終わるように。)
my $pm = Parallel::ForkManager->new(11);


eval{
    my @table = &get_lastmonth_work_table();
    foreach my $tab(@table){
	$pm->start and next;

        my $start_day = &get_start_day($tab);
        my $tmp = &get_min_max_avg($tab,$start_day);

	$pm->finish;
    }
    $pm->wait_all_children;
    print "OK!!!!!!!!!!!!!!!!!!!!!!\n";
};if($@) {
    print "error $@ ";
}

sub get_min_max_avg{
    my $this_func_name = ( caller 0 )[3];

    my $table_val = $_[0] ;
    my $start_day = $_[1] ;
    my ($table_name,$channel_id) = split(/:/, $table_val);


    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";

    my $sql = "SELECT `log_data`,MIN(`response_time`),MAX(`response_time`),AVG(`response_time`)
               FROM $table_name GROUP BY `log_data`;";

    my $sth = $dbh->prepare("$sql") or die "SQL execute error $!";
    $sth->execute or  Log_Text_Controls::error_log("SQL execute error $! $sql");

    my (@list,$resource, $min, $max,$avg,$update_sql) ;

    while (@list = $sth->fetchrow_array()){
        $resource = $list[0] ;
        $min = $list[1] ;
        $max = $list[2] ;
        $avg = $list[3] ;
        my $update_sql = "UPDATE `LOG_ANALYZE_RESOURCE` SET `min_response_time`='$min',
              `max_response_time`='$max', `avg_response_time`='$avg'
              WHERE `datetime`='$start_day' AND `log_data`='$resource' ;";

        my $sth = $dbh->prepare("$update_sql") or die "SQL execute error: $!";
        $sth->execute or  Log_Text_Controls::error_log("SQL execute error $! $sql");
    }
    $sth->finish;
    return 0;
}

sub get_lastmonth_work_table{
    my $this_func_name = ( caller 0 )[3];

    my $last_mon =  join(" ","date",'+"%Y%m"',"-d",'"3 month ago"');
    $last_mon = `$last_mon`;
    $last_mon =~ s/\n// ;
    #完了したテーブルを見てきて必要な情報貰う

    my $sql_get_table = "SELECT log_table_history.table_name,log_table_history.channel_id,MASTER_CHANNEL.channel_name
        FROM log_table_history INNER JOIN MASTER_CHANNEL
        ON log_table_history.channel_id = MASTER_CHANNEL.channel_id
        AND table_name LIKE '%$last_mon';";

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";
    my $sth = $dbh->prepare("$sql_get_table") or die "sql execute error $!";
    $sth->execute  or die "sql execute error $!";
    my @table_list;
    while (my @ary = $sth->fetchrow_array()){
        my ($table,$channel_id,$channel_name) = @ary;
        my $value = join(":",$table,$channel_id,$channel_name);
        push(@table_list,$value);
    }
    $sth->finish  or die "DB Connection Close error $!" ;
    $dbh->disconnect;

    return @table_list;
}

sub get_start_day{
    my $this_func_name = ( caller 0 )[3];
    my $table_val = $_[0] ;
    my ($table_name,$channel_id) = split(/:/, $table_val);

    $table_name =~ s/\D//g;
    my $mon = substr($table_name,0,4);
    my $day = substr($table_name,4,2);
    my $start_day = sprintf("%d-%s", $mon,$day);

    if ($start_day !~ /20[0-9][0-9]-(0[1-9]|1[0-2])/ ){
        die "date error $!  : $start_day ";
    }

    return $start_day;
}


