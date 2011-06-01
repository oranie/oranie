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

my @sec_counttime = (0,1,2,3,4,5,10,30,60);

#並列実行をとりあえず8で
my $pm = Parallel::ForkManager->new(8);

#本スクリプトの実行処理
eval{
    my @table = &get_lastmonth_work_table( 'DBI:mysql:slow_log','root','hogehoge');
    foreach my $sec_time (@sec_counttime){
        foreach my $table_value(@table){
            $pm->start and next;
            my @day_list = &get_start_end_day($table_value);
            foreach my $day (@day_list) {
                &init_table($table_value,$day,$sec_time);
                &update_summary($table_value,$day,$sec_time);
            }
            $pm->finish;
        }
        $pm->wait_all_children;
    }
    Log_Text_Controls::error_log("All end ");
    Log_Mail_Controls::mail_send("end" ,"on");
};if($@) {
    Log_Text_Controls::error_log($@);
    Log_Mail_Controls::mail_send("$@","on");
}


