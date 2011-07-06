#!/usr/bin/perl

package Log_DB_Controls;

use strict;
use warnings;
use HTTP::Date;
use Date::Simple;
use Config::Simple;

#print create_table_sql(shift);

my $cfgObj = new Config::Simple;
$cfgObj->read('./lib/config.pm');
my $cfg = $cfgObj->vars();
my $d = $cfg->{'database.db'};
my $u = $cfg->{'database.user'};
my $p = $cfg->{'database.password'};


sub insert_pre_sql{
    my $inser_pre_sql = <<"EOF";
    SET GLOBAL innodb_flush_log_at_trx_commit = 0;
    SET sql_mode = 'STRICT_ALL_TABLES';
EOF
    return $inser_pre_sql;
}

sub insert_after_sql{
    my $table_name = $_[0];
    my $channel_id = $_[1];
    my $table_name_1sec = join('',"$table_name","_over1sec");
    my $now_time = HTTP::Date::time2iso();
    my $table_value =  join( "','", $table_name,$now_time,$channel_id);   
    my $table1sec_value =  join( "','", $table_name_1sec,$now_time,$channel_id);   

    my $insert_after_sql = <<"EOF";
    ALTER TABLE log_data RENAME TO $table_name ;
    SET GLOBAL innodb_flush_log_at_trx_commit = 1;
    CREATE TABLE `$table_name_1sec` AS SELECT * FROM `$table_name` WHERE `response_time` >= 1000 ;
    INSERT INTO log_table_history(`table_name`,`history_date`,`channel_id`) value ('$table_value');
    INSERT INTO log_table_history(`table_name`,`history_date`,`channel_id`) value ('$table1sec_value');
    UPDATE log_table_history SET `over1sec` = 1 WHERE `table_name` LIKE '${table_name}%';
EOF
    return $insert_after_sql;
}
 
sub check_table_sql{
    my $table_name = $_[0];
    my $check_table_sql = <<"EOF";
    SELECT table_name FROM log_table_history WHERE table_name = '$table_name' ;
EOF
    return $check_table_sql;
}

sub create_table_sql{
    my $create_table_sql = <<"EOF";
        DROP TABLE IF EXISTS `log_data`;
        SET \@saved_cs_client     = \@\@character_set_client;
        SET character_set_client = utf8;
        CREATE TABLE `log_data` ( `log_id` INT(11) unsigned NOT NULL auto_increment,`datetime` datetime NOT NULL,`method` varchar(20) NOT NULL,`log_data` varchar(512) NOT NULL,`parametor` text,`response_code` smallint(5) unsigned NOT NULL,`response_size` int(11) unsigned NOT NULL,`response_time` int NOT NULL,`host_name` varchar(40) NOT NULL,`channel_id` int(11) unsigned NOT NULL, PRIMARY KEY  (`log_id`),UNIQUE KEY `log_id` (`log_id`),KEY `channel_id` (`channel_id`),INDEX log_data_idx(log_data),INDEX response_time_idx(response_time)  ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ;
EOF
    return $create_table_sql;
}

sub rename_table_sql{
    my $file_name = shift or die "No File!! $!";
    my $channel_name = shift or die "No Channel Name!! $!";

    open my $fh, "zcat $file_name 2>/dev/null |"
        or die "Can't zcat '$file_name' for reading: $!";

    my $line = <$fh>;
    my %log_hash = ();
    ($log_hash{date}, $log_hash{method}, $log_hash{resource}, $log_hash{response_code}, 
        $log_hash{response_size}, $log_hash{response_time},$log_hash{host_name}) = split(/,/, $line) ;

    #ログから何月分のログか判定するが、ローテートの関係でギリギリ前月分が入った時を考え1日+してその月を取得する。
    my $date = HTTP::Date::time2iso(str2time($log_hash{date}));
    $date =~ s/ .*//g;
    my @date = split('-',$date);
    $date = Date::Simple->new($date[0],$date[1],$date[2]);
    $date = $date->next;

    #1日+した日付からyyyymmを求める
    @date = split(/\-/, $date);
    $date = join('', $date[0],$date[1]);

    my $rename_table_sql = "log_data_$channel_name$date";
    return $rename_table_sql;
}

sub get_channel_info_from_file{
#チャネルマスタ情報取得
    my $sql = "select channel_id,channel_name from MASTER_CHANNEL";
    my $d = $_[0];
    my $u = $_[1];
    my $p = $_[2];
    my $file = $_[3];

    #一時的に利用する変数初期化
    my $chanel_id = 0;
    my $name = "";

    # データベースへ接続
    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";

    #マスタからデータ引っ張って、ログ登録用のIDを設定する。
    my $sth = $dbh->prepare("$sql") or die "sql execute error $!";
    $sth->execute  or die "sql execute error $!";
    my %hash = ();
    while (my @ary = $sth->fetchrow_array()){
        my ($no , $name) = @ary;
        $hash{$name} = $no;
    }
    $sth->finish  or die "DB Connection Close error $!" ;
    $dbh->disconnect;

    foreach  my $chanel_name (keys %hash){
        if ( $file =~ $chanel_name ){
            $chanel_id = $hash{$chanel_name};
            $name = $chanel_name;
            last;
        }
    }
    return ($chanel_id ,$name);
}

sub log_table_history_update{
    my $this_func_name = ( caller 0 )[3];
    Log_Text_Controls::error_log("$this_func_name start @_");

    my $table_value = $_[0];
    my $column_name = $_[1];
    my ($table_name,$channel_id,$channel_name) = split(/:/, $table_value);

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";
    my $sth;

    my $update_sql = "UPDATE `log_table_history` SET `$column_name` = 1 WHERE `table_name` LIKE '${table_name}%'; ";
    $sth = $dbh->prepare("$update_sql") or die "sql execute error $! : $update_sql";
    $sth->execute  or die "sql execute error $!  : $update_sql ";
    $sth->finish  or die "DB Connection Close error $!" ;


    Log_Text_Controls::error_log("$this_func_name end $update_sql");
    return 0;
}


return 1;
