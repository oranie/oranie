#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Date;
use IO::File;
use DBD::mysql;
use DBI;

#Log_DB_Controlsパッケージの読み込み
require "./log_db_control.pm";
require "./log_text_control.pm";

my $file = shift or die "No File!! $!";

my $d = 'DBI:mysql:slow_log';
my $u = 'root';
my $p = 'hogehoge';

#チャネルIDを取得します。
my @get_channel_info = Log_DB_Controls::get_channel_info_from_file($d,$u,$p,$file);
my $channel_id = $get_channel_info[0];
my $channel_name = $get_channel_info[1];

#このスクリプトを実行
eval{
    Log_Text_Controls::error_log("start $file");
    open_gz_to_db($file, $channel_id,$channel_name);
    Log_Text_Controls::error_log("end $file");
};
if($@){
    Log_Text_Controls::error_log($@);
}

#sub start_execute_check_db{
#    my $table_name = @[0];
#    my $c = Log_DB_Controls::check_table_sql($table_name);
#    if ( $c ne 0){
#        return 1;
#    }
#}

#gzファイルをopenして、整形しSQLを発行、DBにINSERT。
sub open_gz_to_db{
    my $file_name = shift or die "No File!! $! ";
    my $channel_id = shift or die "No Channel ID!! $!";
    my $channel_name = shift or die "No Channel Name!! $!";

    my $sql_head = "INSERT INTO log_data(datetime,method,log_data,parametor,response_code,response_size,response_time,channel_id) value ";
    my $sql_last = "ALTER TABLE log_data RENAME TO log_data_$channel_name";

    my $table_last_name =  Log_DB_Controls::rename_table_sql($file_name,$channel_name);
    my $table_name = "log_data_$table_last_name";
    my $now_time = HTTP::Date::time2iso();
    my $table_value =  join( "','", $table_name,$now_time,$channel_id); 

    my @tmp = ();
    #とりあえず300件ずつcommitするためのカウンター
    my $i = 0;

    print Log_DB_Controls::insert_pre_sql();
    print Log_DB_Controls::create_table_sql();

    open my $fh, "zcat $file_name 2>/dev/null |"
        or die "Can't zcat '$file_name' for reading: $!";
    while ( my $line = <$fh> ) {
        chomp $line;
        my $sql = Log_Text_Controls::create_insert_sql($line,$channel_id);
        if ($sql eq "1"){
            Log_Text_Controls::error_log("\n[crit]log parse error open_gz_to_db \n");
            next;
        }

        push(@tmp , ($sql));

        if ($i > 299){
           my $tmp = join(',', @tmp);
           print "$sql_head $tmp ;\n";
           @tmp = ();
           $i = 0;
        }
        $i++;
    }
    my $tmp = join(',', @tmp);

    print "$sql_head $tmp ;\n";
    print "ALTER TABLE log_data RENAME TO $table_name ;\n";
    print "INSERT INTO log_table_history value ('$table_value');\n";
    print Log_DB_Controls::insert_after_sql();

    close $fh
        or die "Can't close '$file_name' after reading: $!";
}

