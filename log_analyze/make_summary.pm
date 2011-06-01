#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Date;
use Date::Simple;
use IO::File;
use DBD::mysql;
use DBI;

my $d = 'DBI:mysql:slow_log';
my $u = 'root';
my $p = 'hogehoge';

#作業対象のテーブルを取得する。基本はバッチ処理実行の1ヶ月前だけ対象
sub get_lastmonth_work_table{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("All start $this_func_name");
    my $last_mon =  join(" ","date",'+"%Y%m"',"-d",'"2 month ago"');
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

#作業対象の日付範囲を取得する。
sub get_start_end_day{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start $_[0]");
    my $table_val = $_[0] ;
    my ($table_name,$channel_id) = split(/:/, $table_val);

    my @sql;
    $sql[0] = "SELECT DATE(MIN(datetime)) FROM $table_name ;";
    $sql[1] = "SELECT DATE(MAX(datetime)) FROM $table_name ;";

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";
    my @date;
    foreach my $s (@sql){
        my $sth = $dbh->prepare("$s") or die "sql execute error $!";
        $sth->execute  or die "sql execute error $!";
        push(@date, $sth->fetchrow_array());
    }

    my $start_day = Date::Simple->new($date[0]);
    my $end_day = Date::Simple->new($date[1]);
    my @day_list;
    $end_day = $end_day->next;

    while ($start_day ne $end_day ) {
        push(@day_list,$start_day);
        $start_day = $start_day->next;
    }
    return @day_list;
}

#先に日付など必要な値をINSERTする
sub init_table{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name     start @_");
    my $table_value = $_[0];
    my $day = $_[1];
    my $sec = $_[2];

    my ($table_name,$channel_id,$channel_name) = split(/:/, $table_value);
    my $date_host_sec = join(' ',$day,$channel_name,$sec);

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";
    my $sql = "INSERT INTO LOG_ANALYZE_TOTAL_EVERY_TIME(`date_and_host`,`history_date`,`channel_id`,`over_sec_type`) value 
                ('$date_host_sec','$day',$channel_id,$sec);";
    my $sth = $dbh->prepare("$sql") or die "sql execute error $!";
    $sth->execute or  Log_Text_Controls::error_log("Maybe INSERTED ! sql execute error $! $sql");
    $sth->finish  or die "DB Connection Close error $!" ;
    $dbh->disconnect or die "DB Connection Close error $!";
    return 0;
}



#update_summary()で使うテーブル名チェック関数
sub rename_table{
    my $table_value = $_[0] ;
    my $sec = $_[1];

    my ($table_name,$channel_id,$channel_name) = split(/:/, $table_value);

    if ($sec > 0 ){
        #1秒以上掛かっている場合は事前に分割したテーブルの方を参照する為テーブル名を変更
        $table_name = join('',$table_name,"_over1sec");
    } elsif ($sec == 0) {
        #0秒だったらなにもしない
    } else {
        #nullだったらエラー
        die "$sec is not value $!";
    }
    $table_value = join(':',$table_name,$channel_id,$channel_name);
    return $table_value;
}


#各日付、時間帯毎の集計を行い、UPDATEしていく。
sub update_summary{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start @_");

    my $table_value = $_[0] ;
    my $day = $_[1];
    my $sec = $_[2];

    $table_value = &rename_table($table_value,$sec);
    my ($table_name,$channel_id,$channel_name) = split(/:/, $table_value);   

    my $date_host_sec = join(' ',$day,$channel_name,$sec);
    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";
    my $sth;
    
    #secをミリ秒に変える
    my $count_sec = $sec * 1000;
    my $count_sql = "SELECT COUNT(`log_id`),`channel_id` FROM $table_name 
        WHERE `response_time` >= $count_sec AND `datetime` LIKE '$day%' AND HOUR(`datetime`) = ";

    for (my $hour = 00; $hour <= 23; $hour++){
        my $count_sql = join('',"$count_sql","$hour ;");
        $sth = $dbh->prepare("$count_sql") or die "sql execute error $!";
        $sth->execute  or die "sql execute error $! : $count_sql";
        while (my @ary = $sth->fetchrow_array()){
            my ($count , $id) = @ary ;
            my $check_sql = "SELECT `$hour` FROM `slow_log`.`LOG_ANALYZE_TOTAL_EVERY_TIME` 
                WHERE `date_and_host` = '$date_host_sec' AND `over_sec_type` = $sec ;";

            my $sth = $dbh->prepare("$check_sql") or die "sql execute error $! : $check_sql";
            $sth->execute  or die "sql execute error $!  : $check_sql ";
            my $ary = $sth->fetchrow_array() || 0 ;
            if ($ary > 0 ){
                $count = $count + $ary;
            }
            my $update_sql = "UPDATE `LOG_ANALYZE_TOTAL_EVERY_TIME` SET `$hour` = '$count' 
                WHERE `date_and_host` = '$date_host_sec' AND `over_sec_type` = $sec  ;";

            $sth = $dbh->prepare("$update_sql") or die "sql execute error $! : $update_sql";
            $sth->execute  or die "sql execute error $!  : $update_sql ";
            
        }
    }

    $sth->finish  or die "DB Connection Close error $!" ;
    return 0;
}

