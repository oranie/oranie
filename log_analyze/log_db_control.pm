#!/usr/bin/perl

package Log_DB_Controls;

use strict;
use warnings;
use HTTP::Date;

#print create_table_sql(shift);

sub insert_pre_sql{
    my $inser_pre_sql = <<"EOF";
    SET GLOBAL innodb_flush_log_at_trx_commit = 2;
    SET sql_mode = 'STRICT_ALL_TABLES';
EOF
    return $inser_pre_sql;
}

sub insert_after_sql{
    my $inser_after_sql = <<"EOF";
    SET GLOBAL innodb_flush_log_at_trx_commit = 1;
EOF
    return $inser_after_sql;
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
        CREATE TABLE `log_data` ( `log_id` int(11) unsigned NOT NULL auto_increment,`datetime` datetime NOT NULL,`method` varchar(20) NOT NULL,`log_data` text NOT NULL,`parametor` text,`response_code` smallint(5) unsigned NOT NULL,`response_size` int(11) unsigned NOT NULL,`response_time` int NOT NULL,`host_name` varchar(40) NOT NULL,`channel_id` int(11) unsigned NOT NULL, PRIMARY KEY  (`log_id`),UNIQUE KEY `log_id` (`log_id`),KEY `channel_id` (`channel_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ;
EOF
    return $create_table_sql;
}
=pod
上のSQL文
        DROP TABLE IF EXISTS `log_data`;
        SET \@saved_cs_client     = \@\@character_set_client;
        SET character_set_client = utf8;
        CREATE TABLE `log_data` (
           `log_id` int(11) unsigned NOT NULL auto_increment,
           `datetime` datetime NOT NULL,
           `method` varchar(20) NOT NULL,
           `log_data` text NOT NULL,
           `parametor` text,
           `response_code` smallint(5) unsigned NOT NULL,
           `response_size` int(11) unsigned NOT NULL,
           `response_time` int NOT NULL,
           `host_name` varchar(20) NOT NULL,
           `channel_id` int(11) unsigned NOT NULL,
       PRIMARY KEY  (`log_id`),
       UNIQUE KEY `log_id` (`log_id`),
       KEY `channel_id` (`channel_id`)
     ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ;
=cut

sub rename_table_sql{
    my $file_name = shift or die "No File!! $!";
    my $channel_name = shift or die "No Channel Name!! $!";

    open my $fh, "zcat $file_name 2>/dev/null |"
        or die "Can't zcat '$file_name' for reading: $!";

    my $line = <$fh>;
    my %log_hash = ();
    ($log_hash{date}, $log_hash{method}, $log_hash{resource}, $log_hash{response_code}, 
        $log_hash{response_size}, $log_hash{response_time},$log_hash{host_name}) = split(/,/, $line) ;

    my $date = HTTP::Date::time2iso(str2time($log_hash{date}));
    my @date = split(/\-/, $date);
    $date = join('', $date[0],$date[1]);

    my $rename_table_sql = "$channel_name$date";
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

return 1;
