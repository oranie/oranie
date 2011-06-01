#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Date;
use Date::Simple;
use IO::File;
use DBD::mysql;
use DBI;
use Parallel::ForkManager;

#package読み込み
require "./log_db_control.pm";
require "./log_text_control.pm";
require "./log_mail_control.pm";
require "./make_summary.pm";

my $d = 'DBI:mysql:slow_log';
my $u = 'root';
my $p = 'hogehoge';

#並列実行をとりあえず8で
my $pm = Parallel::ForkManager->new(8);

eval{
    my @table = &get_lastmonth_work_table( 'DBI:mysql:slow_log','root', 'yura0244');
    foreach my $table_value(@table){
        $pm->start and next;
        my @resource_list = &get_resource_list($table_value);
        foreach my $resource (@resource_list){
            my $start_day = &get_start_day($table_value);
            my $tmp = &resource_init_table($table_value,$resource,$start_day);
            my $resource = &get_count_resource($table_value,$resource,$start_day);
            print "$start_day  $tmp  $resource\n";
        }
        $pm->finish;
    }
    $pm->wait_all_children;
    Log_Text_Controls::error_log("All end ");
};if($@) {
    Log_Text_Controls::error_log("ERROR END $@");
}

sub get_start_day{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start $_[0]");
    my $table_val = $_[0] ;
    my ($table_name,$channel_id) = split(/:/, $table_val);

    my $sql = "SELECT DATE(MIN(datetime)) FROM $table_name ;";

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";

    my $sth = $dbh->prepare("$sql") or die "sql execute error $!";
    $sth->execute  or die "sql execute error $!";

    my $start_day = $sth->fetchrow_array();    
    $start_day = Date::Simple->new($start_day);
    $start_day = $start_day->format('%Y-%m');

    return $start_day;
}

sub get_resource_list{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start $_[0]");
    my $table_val = $_[0] ;
    my ($table_name,$channel_id) = split(/:/, $table_val);

    my $sql = "SELECT DISTINCT `log_data` FROM `slow_log`.`$table_name` ORDER BY `log_data` ;";
 
    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";

    my $sth = $dbh->prepare("$sql") or die "sql execute error $!";
    $sth->execute  or die "sql execute error $!";

    my @resource_list;
    while (my $list = $sth->fetchrow_array()){
        push(@resource_list, $list);
    }
    return @resource_list;
}

sub resource_init_table{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name     start @_");
    my $table_value = $_[0];
    my $resource_name = $_[1];
    my $datetime = $_[2];

    my ($table_name,$channel_id,$channel_name) = split(/:/, $table_value);

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";

    my $sql = "INSERT INTO LOG_ANALYZE_RESOURCE(`datetime`,`channel_id`,`log_data`) value
                ('$datetime','$channel_id','$resource_name');";

    print "$sql\n:";
    my $sth = $dbh->prepare("$sql") or die "sql execute error $!";
    $sth->execute or  Log_Text_Controls::error_log("Maybe INSERTED ! sql execute error $! $sql");
    $sth->finish  or die "DB Connection Close error $!" ;
    $dbh->disconnect or die "DB Connection Close error $!";

    return 0;
}


sub get_count_resource{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start $_[0]");
    my %column_list = (
        "total_request" => 0,
        "over1sec_request" => 1,
        "over5sec_request" => 5,
        "over10sec_request" => 10,
        "over30sec_request" => 30,
        "over60sec_request" => 60
    );

    my $table_val = $_[0] ;
    my ($table_name,$channel_id) = split(/:/, $table_val);
    my $resource_name = $_[1] ;
    my $start_day = $_[2] ;

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";
    my $sth ;
    while ( my ($column_name, $sec) = each(%column_list) ){
        my $work_table_name;
        if ($column_name ne "total_request"){
            $work_table_name = join('',$table_name,"_over1sec"); 
        }else{
            $work_table_name = $table_name;
        }
        my $count_sec = $sec * 1000 ;

        my $count_sql = "SELECT COUNT(`log_data`) FROM $work_table_name 
                    WHERE `log_data` = '$resource_name' AND `response_time` >= $count_sec ;";

        print "$count_sql\n";

        $sth = $dbh->prepare("$count_sql") or die "sql execute error $!";
        $sth->execute  or die "sql execute error $!";

        my $count = $sth->fetchrow_array();

        my $check_sql = "SELECT `$column_name` FROM `slow_log`.`LOG_ANALYZE_RESOURCE` 
                        WHERE `datetime` = '$start_day' AND log_data = '$resource_name';";

        $sth = $dbh->prepare("$check_sql") or die "sql execute error $! : $check_sql";
        $sth->execute  or die "sql execute error $!  : $check_sql ";

        my $ary = $sth->fetchrow_array() || 0 ;
        if ($ary > 0 ){
            $count = $count + $ary;
        }

        my $update_sql = "UPDATE `LOG_ANALYZE_RESOURCE` SET `$column_name` = '$count'
            WHERE `datetime` = '$start_day' AND log_data = '$resource_name';";

        $sth = $dbh->prepare("$update_sql") or die "sql execute error $! : $update_sql";
        $sth->execute  or die "sql execute error $!  : $update_sql ";


    }    
    $sth->finish  or die "DB Connection Close error $!" ;
    return 0;
}

