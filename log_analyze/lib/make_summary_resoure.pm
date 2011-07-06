#!/usr/bin/perl

package Make_Summary_Resource;

use strict;
use warnings;
use HTTP::Date;
use Date::Simple;
use IO::File;
use DBD::mysql;
use DBI;
use Parallel::ForkManager;
use Config::Simple;

#package読み込み
require "./lib/log_db_control.pm";
require "./lib/log_text_control.pm";
require "./lib/log_mail_control.pm";
#require "./make_summary.pm";

my $cfgObj = new Config::Simple;
$cfgObj->read('./lib/config.pm');
my $cfg = $cfgObj->vars();
my $d = $cfg->{'database.db'};
my $u = $cfg->{'database.user'};
my $p = $cfg->{'database.password'};

sub get_lastmonth_work_table{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("All start $this_func_name");

    my $column_name = $_[0];
    my $last_mon =  join(" ","date",'+"%Y%m"',"-d",'"3 month ago"');
    $last_mon = `$last_mon`;
    $last_mon =~ s/\n// ;
    #完了したテーブルを見てきて必要な情報貰う

    my $sql_get_table = "SELECT log_table_history.table_name,log_table_history.channel_id,MASTER_CHANNEL.channel_name
        FROM log_table_history INNER JOIN MASTER_CHANNEL
        ON log_table_history.channel_id = MASTER_CHANNEL.channel_id
        AND table_name LIKE '%$last_mon' AND `$column_name` = 0 ;";

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
    Log_Text_Controls::error_log("$this_func_name start $_[0]");
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

sub rename_table{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start @_");

    my $table_name = $_[0];
    my $column_name = $_[1];

    if ($column_name ne "total_request"){
        $table_name = join('',$table_name,"_over1sec") || die "error $!";
    }else{
        $table_name = $table_name || die "error $!";
    }

    Log_Text_Controls::error_log("$this_func_name end $table_name");
    return $table_name;
}

sub get_resource_list{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start $_[0]");
    my $table_val = $_[0] ;
    my $column_name = $_[1] ;
    my ($table_name,$channel_id) = split(/:/, $table_val);

    $table_name = &rename_table($table_name ,$column_name);

    my $sql = "SELECT DISTINCT `log_data` FROM `slow_log`.`$table_name` ORDER BY `log_data` ;";
 
    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";

    my $sth = $dbh->prepare("$sql") or die "sql execute error $!";
    $sth->execute  or die "sql execute error $!";

    my @resource_list;
    while (my $list = $sth->fetchrow_array()){
        push(@resource_list, $list);
    }

    Log_Text_Controls::error_log("$this_func_name end $sql  @resource_list");
    return @resource_list;
}

sub resource_init_table{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name  start @_");
    my $table_value = $_[0];
    my $resource_name = $_[1];
    my $datetime = $_[2];

    my ($table_name,$channel_id,$channel_name) = split(/:/, $table_value);

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";

    my $sql = "INSERT INTO LOG_ANALYZE_RESOURCE(`datetime`,`channel_id`,`log_data`) value
                ('$datetime','$channel_id','$resource_name');";

    my $sth = $dbh->prepare("$sql") or die "sql execute error $!";
    $sth->execute or  Log_Text_Controls::error_log("Maybe INSERTED ! sql execute error $! $sql");
    $sth->finish  or die "DB Connection Close error $!" ;
    $dbh->disconnect or die "DB Connection Close error $!";

    Log_Text_Controls::error_log("$this_func_name  end $table_name,$channel_id,$channel_name");
    return 0;
}

sub get_min_max_avg{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name  start @_");

    my $table_val = $_[0] ;
    my $start_day = $_[1] ;
    my ($table_name,$channel_id) = split(/:/, $table_val);

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";

    my $sql = "SELECT `log_data`,MIN(`response_time`),MAX(`response_time`),AVG(`response_time`),
               STD(`response_time`),VARIANCE(`response_time`),STDDEV_SAMP(`response_time`),VAR_SAMP(`response_time`) 
               FROM $table_name GROUP BY `log_data`;";

    my $sth = $dbh->prepare("$sql") or die "SQL execute error $!";
    $sth->execute or  Log_Text_Controls::error_log("SQL execute error $! $sql");

    my (@list,$resource, $min, $max,$avg,$std,$variance,$stddev_samp,$var_samp,$update_sql) ;

    while (@list = $sth->fetchrow_array()){
        $resource = $list[0] ;
        $min = $list[1] || 0 ;
        $max = $list[2] || 0 ;
        $avg = $list[3] || 0 ;
        $std = $list[4] || 0 ;
        $variance = $list[5] || 0 ;
        $stddev_samp = $list[6] || 0;
        $var_samp = $list[7] || 0;

        my $update_sql = "UPDATE `LOG_ANALYZE_RESOURCE` SET `min_response_time` = '$min',
              `max_response_time` = '$max' , `avg_response_time` = '$avg',
              `std` = '$std', `variance` = '$variance', `stddev_samp` = '$stddev_samp', `var_samp` = '$var_samp'
              WHERE `datetime`='$start_day' AND `log_data`='$resource' ;";

        my $sth = $dbh->prepare("$update_sql") or die "SQL execute error $! $update_sql";
        $sth->execute or  Log_Text_Controls::error_log("SQL execute error $! $dbh->errstr $update_sql");
    }
    $sth->finish;
    Log_Text_Controls::error_log("$this_func_name  end @_");
    return 0;
}


sub get_count_resource{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name  start @_");

    my $table_val = $_[0] ;
    my ($table_name,$channel_id) = split(/:/, $table_val);
    my $resource_name = $_[1] ;
    my $start_day = $_[2] ;
    my $column_name = $_[3];
    my $sec = $_[4];

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";
    my $sth ;

    $table_name = &rename_table($table_name ,$column_name);

    my $count_sec = $sec * 1000 ;


    my $count_sql = "SELECT COUNT(`log_data`) FROM $table_name
                     WHERE `log_data` = '$resource_name' AND `response_time` >= $count_sec ;";

    $sth = $dbh->prepare("$count_sql") or die "sql execute error $!";
    $sth->execute  or die "sql execute error $!";
    my $count = $sth->fetchrow_array() || 0;

    my $update_sql = "UPDATE `LOG_ANALYZE_RESOURCE` SET `$column_name` = '$count'
                      WHERE `datetime` = '$start_day' AND log_data = '$resource_name';";

    $sth = $dbh->prepare("$update_sql") or die "sql execute error $! : $update_sql";
    $sth->execute  or die "sql execute error $! $dbh->errstr : $update_sql ";
    $sth->finish  or die "DB Connection Close error $!" ;

    Log_Text_Controls::error_log("$this_func_name  end @_");
    return 0;
}

