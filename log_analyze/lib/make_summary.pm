#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Date;
use Date::Simple;
use IO::File;
use DBD::mysql;
use DBI;
use Parallel::ForkManager;
use Config::Simple;

my $cfgObj = new Config::Simple;
$cfgObj->read('./lib/config.pm');
my $cfg = $cfgObj->vars();
my $d = $cfg->{'database.db'};
my $u = $cfg->{'database.user'};
my $p = $cfg->{'database.password'};

#作業対象のテーブルを取得する。基本はバッチ処理実行の1ヶ月前だけ対象
sub get_lastmonth_work_table{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("All start $this_func_name");

    my $column_name = $_[0];
    my $last_mon =  join(" ","date",'+"%Y%m"',"-d",'"1 month ago"');
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
                ('$date_host_sec','$day',$channel_id,'$sec');";
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

    if ($sec =~ /avg/) {
       ; #平均だったらなにもしない
    }else{
        if ($sec > 0 ){
            #1秒以上掛かっている場合は事前に分割したテーブルの方を参照する為テーブル名を変更
            $table_name = join('',$table_name,"_over1sec");
        } elsif ($sec == 0) {
            ;#0秒だったらなにもしない
        } else {
            #nullだったらエラー
            die "$sec is not value $!";
        }
    }
    $table_value = join(':',$table_name,$channel_id,$channel_name);
    return $table_value;
}

sub update_init{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start @_");

    my $table_value = $_[0] ;
    my $day = $_[1];
    my $sec = $_[2];

    $table_value = &rename_table($table_value,$sec);
    my ($table_name,$channel_id,$channel_name) = split(/:/, $table_value);

    my $date_host_sec = join(' ',$day,$channel_name,$sec);

    #secをミリ秒に変える。avgはミリ秒変換しないで平均計算のみ
    my $count_sql;
    if ($sec =~ /^[0-9].*/g){
        my $count_sec = $sec * 1000;
        $count_sql = "SELECT COUNT(`log_id`),`channel_id` FROM $table_name
            WHERE `response_time` >= $count_sec AND `datetime` LIKE '$day%' AND HOUR(`datetime`) = ";
    }else{
        $count_sql = "SELECT AVG(`response_time`),`channel_id` FROM $table_name
            WHERE `datetime` LIKE '$day%' AND HOUR(`datetime`) = ";
    }

    my @list = ($date_host_sec,$sec,$day,$count_sql);
    Log_Text_Controls::error_log("$this_func_name end @list");

    return @list;
}


sub update_check {
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start @_");

    my $result_val = $_[0];
    my $check_val =  $_[1];
    my $sec =        $_[2];
    my $check_day =  $_[3];
    my $hour =       $_[4];
    my $flag = 0;

    if($check_val == 0){   #チェック結果が0だったら何もしない。
        ;
    }elsif($check_val > 0 && $sec =~ /^[0-9].*/ ){     #チェック結果が0より大きく、単純なカウントの場合は加算してUPDATEする。
        $result_val = $result_val + $check_val;
    }elsif($check_val > 0 &&  $sec =~ /avg/ && $check_day == 1){     #月初の数値が入り込んだ場合は何もしない
        ;
    }elsif($check_val > 0 &&  $sec =~ /avg/ && $check_day > 1 ){   #平均計算でチェック結果が0より大きく、かつ月初で無い場合UPDATEしないでループを進める。
        $flag = 1;
    }else{
        die "CHECK ERROR $! :: check_val:$check_val,count:$result_val,hour:$hour";
    }

    my @list = ($result_val,$flag);
    Log_Text_Controls::error_log("$this_func_name end @list");

    return @list;
}


sub update_summary{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start @_");

    my @list = &update_init(@_);
    my ($date_host_sec,$sec,$day,$sql_format) = @list;

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";
    my $sth;

    #0-23時のループ
    for (my $hour = 00; $hour <= 23; $hour++){

        my $count_sql = join('',"$sql_format","'$hour' ;");
        $sth = $dbh->prepare("$count_sql") or die "sql execute error $!";
        $sth->execute  or die "sql execute error $! : $count_sql";

        my $check_day = $day;
        $check_day = substr($check_day,-2);
        #カウント結果のループ
        while (my @result = $sth->fetchrow_array()){
            my ($count , $id) = @result ;
            if (defined($count) && $count > 0 ){
                ;
            }else{
                $count = 0;
            }

            #0だった場合はそもそも何もしないでスキップ
            if ($count == 0 ){
                next;
            }else{
                #既に計算結果が入っている場合はマージする。AVG計算の場合は計算結果を省く。
                my $check_sql = "SELECT `$hour` FROM `slow_log`.`LOG_ANALYZE_TOTAL_EVERY_TIME`
                    WHERE `date_and_host` = '$date_host_sec' AND `over_sec_type` = '$sec' ;";

                my $sth = $dbh->prepare("$check_sql") or die "sql execute error $! : $check_sql";
                $sth->execute  or die "sql execute error $!  : $check_sql ";

                my @check_result = $sth->fetchrow_array() || 0 ;
                my @check_list = &update_check($count,@check_result,$sec,$check_day,$hour);
                $count = $check_list[0];
                my $flag = $check_list[1];
                if ($flag == 1){
                    next;
                }

                my $update_sql = "UPDATE `LOG_ANALYZE_TOTAL_EVERY_TIME` SET `$hour` = '$count'
                    WHERE `date_and_host` = '$date_host_sec' AND `over_sec_type` = '$sec'  ;";

                $sth = $dbh->prepare("$update_sql") or die "sql execute error $! : $update_sql";
                $sth->execute  or die "sql execute error $!  : $update_sql ";

                Log_Text_Controls::error_log("UPDATE!! $date_host_sec,$hour,$count,$sec");
            }
        }
    }
    $sth->finish  or die "DB Connection Close error $!" ;
    return 0;
}

