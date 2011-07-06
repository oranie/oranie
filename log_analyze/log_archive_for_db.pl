#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Date;
use IO::File;
use File::Find;
use Parallel::ForkManager;

#Log_DB_Controlsパッケージの読み込み
require "./lib/log_db_control.pm";
require "./lib/log_text_control.pm";
require "./lib/log_parse.pm";
require "./lib/log_mail_control.pm";

my $pm = Parallel::ForkManager->new(2);

my @channel = ("server1","server2");

eval{
    Log_Text_Controls::error_log("------------------------------START ALL LOG PARSE");

    foreach my $channel(@channel){
        $pm->start and next;
        my $tmp = Log_Parser::web_log_parser("$channel");
        print "$tmp\n";
        Log_Parser::parse_log_compress($tmp);
        $pm->finish;
    }
    $pm->wait_all_children;

    Log_Text_Controls::error_log("------------------------------FINISH ALL LOG PARSE");
    Log_Mail_Controls::mail_send("end log_analyze","on");
};
if($@){
    Log_Text_Controls::error_log("[Crit] : $@");
    Log_Mail_Controls::mail_send("$@","on");
}

