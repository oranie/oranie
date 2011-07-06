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

require "./lib/make_summary_resoure.pm";

my $cfgObj = new Config::Simple;
$cfgObj->read('./lib/config.pm');
my $cfg = $cfgObj->vars();
my $d = $cfg->{'database.db'};
my $u = $cfg->{'database.user'};
my $p = $cfg->{'database.password'};


my %column_list = (
    "total_request" => 0,
    "over1sec_request" => 1,
    "over5sec_request" => 5,
    "over10sec_request" => 10,
    "over30sec_request" => 30,
    "over60sec_request" => 60
);


#並列実行をとりあえず11で
my $pm = Parallel::ForkManager->new(11);
#my $this_func_name = ( caller 0 )[3];
my $this_func_name = $0;

my $db_history_column_name = "LOG_ANALYZE_RESOURCE";

eval{
    Log_Text_Controls::error_log("$this_func_name START ");
    my @table = Make_Summary_Resource::get_lastmonth_work_table($db_history_column_name);
    foreach my $table_value(@table){
        my $start_day = Make_Summary_Resource::get_start_day($table_value);
        while ( my ($column_name, $sec) = each(%column_list) ){
            my @resource_list = Make_Summary_Resource::get_resource_list($table_value,$column_name);
            foreach my $resource (@resource_list){
                $pm->start and next;
                if ($sec == 0){
                    Make_Summary_Resource::resource_init_table($table_value,$resource,$start_day);
                }
                my $resource = Make_Summary_Resource::get_count_resource($table_value,$resource,$start_day,$column_name,$sec);
                $pm->finish;
            }
            $pm->wait_all_children;
        }
        Make_Summary_Resource::get_min_max_avg($table_value,$start_day);
        Log_DB_Controls::log_table_history_update($table_value,$db_history_column_name);
    }
    Log_Text_Controls::error_log("$this_func_name ALL END ");
    Log_Mail_Controls::mail_send("$this_func_name ALL END" ,"on");
};if($@) {
    Log_Text_Controls::error_log("$this_func_name ERROR END $@");
    Log_Mail_Controls::mail_send("$this_func_name ERROR END $@" ,"on");
}



