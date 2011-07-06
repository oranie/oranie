#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Date;
use IO::File;
use DBD::mysql;
use DBI;

#Log_DB_Controlsパッケージの読み込み
require "./lib/log_db_control.pm";
require "./lib/log_text_control.pm";
require "./lib/log_mail_control.pm";

my $file = shift or die "No File!! $!";

use Config::Simple;

my $cfgObj = new Config::Simple;
$cfgObj->read('./lib/config.pm');
my $cfg = $cfgObj->vars();
my $d = $cfg->{'database.db'};
my $u = $cfg->{'database.user'};
my $p = $cfg->{'database.password'};

#チャネルIDを取得します。
my @get_channel_info = Log_DB_Controls::get_channel_info_from_file($d,$u,$p,$file);
my $channel_id = $get_channel_info[0];
my $channel_name = $get_channel_info[1];

#Log_Mail_Controls::

#このスクリプトを実行
eval{
    Log_Text_Controls::error_log("start $file");
    open_gz_to_db($file, $channel_id,$channel_name);
    Log_Text_Controls::error_log("end $file");
    Log_Mail_Controls::mail_send("end $file","on");
};
if($@){
    Log_Text_Controls::error_log($@);
    Log_Mail_Controls::mail_send("$@","on");
}

#gzファイルをopenして、整形しSQLを発行、DBにINSERT。
sub open_gz_to_db{
    my $file_name = shift or die "No File!! $! ";
    my $channel_id = shift or die "No Channel ID!! $!";
    my $channel_name = shift or die "No Channel Name!! $!";

    my $sql_head = "INSERT INTO log_data(datetime,method,log_data,parametor,response_code,response_size,response_time,host_name,channel_id) value ";
    my $sql_last = "ALTER TABLE log_data RENAME TO log_data_$channel_name";

    my $table_name =  Log_DB_Controls::rename_table_sql($file_name,$channel_name);
    my $now_time = HTTP::Date::time2iso();
    my $table_value =  join( "','", $table_name,$now_time,$channel_id); 

    my @tmp = ();
    #とりあえず500件ずつcommitするためのカウンター
    my $i = 0;

    print Log_DB_Controls::insert_pre_sql();
    print Log_DB_Controls::create_table_sql();

    open my $fh, "zcat $file_name 2>/dev/null |"
        or die "Can't zcat '$file_name' for reading: $!";
    while ( my $line = <$fh> ) {
        chomp $line;
        my $sql = Log_Text_Controls::create_insert_sql($line,$channel_id);
        if ($sql eq "1"){
            Log_Text_Controls::error_log("[crit]log parse error open_gz_to_db \n");
            next;
        }

        push(@tmp , ($sql));

        if ($i > 499){
           my $tmp = join(',', @tmp);
           print "$sql_head $tmp ;\n";
           @tmp = ();
           $i = 0;
        }
        $i++;
    }
    my $tmp = join(',', @tmp);

    print "$sql_head $tmp ;\n";
    print Log_DB_Controls::insert_after_sql($table_name,$channel_id);
    close $fh
        or die "Can't close '$file_name' after reading: $!";
}

