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

#package読み込み
require "./lib/log_db_control.pm";
require "./lib/log_text_control.pm";
require "./lib/log_mail_control.pm";
require "./lib/make_summary.pm";

my $cfgObj = new Config::Simple;
$cfgObj->read('./lib/config.pm');
my $cfg = $cfgObj->vars();
my $d = $cfg->{'database.db'};
my $u = $cfg->{'database.user'};
my $p = $cfg->{'database.password'};


#my @sec_counttime = (0,1,2,3,4,5,10,30,60);
#my @sec_counttime = ("avg",0,1,2,3,4,5,10,30,60);
my @sec_counttime = ("avg");
my $db_history_column_name = "LOG_ANALYZE_TOTAL_EVERY_TIME";

my $this_func_name = $0;

#並列実行をとりあえず11で(3回回せば確実に1ヶ月分終わるように。)
my $pm = Parallel::ForkManager->new(11);

#本スクリプトの実行処理
eval{
    Log_Text_Controls::error_log("$this_func_name START ");
    my @table = &get_lastmonth_work_table($db_history_column_name);
    foreach my $table_value(@table){
    	foreach my $sec_time (@sec_counttime){
            my @day_list = &get_start_end_day($table_value);
            foreach my $day (@day_list) {
                $pm->start and next;
                &init_table($table_value,$day,$sec_time);
                &update_summary($table_value,$day,$sec_time);
                $pm->finish;
            }
            $pm->wait_all_children;
        }
        Log_DB_Controls::log_table_history_update($table_value,$db_history_column_name);
    }
    Log_Text_Controls::error_log("$this_func_name ALL END ");
    Log_Mail_Controls::mail_send("$this_func_name ALL END" ,"on");
};if($@) {
    Log_Text_Controls::error_log("$this_func_name ERROR END $@");
    Log_Mail_Controls::mail_send("$this_func_name ERROR END $@" ,"on");
}

