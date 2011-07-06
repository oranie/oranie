#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Date;
use IO::File;
use File::Find;

package Log_Parser;

#Log_DB_Controlsパッケージの読み込み
require "./lib/log_db_control.pm";
require "./lib/log_text_control.pm";
require "./lib/log_mail_control.pm";

my @channel = ("server1","server2");

sub month_get{
    my $this_mon =  join(" ","date",'+"%Y-%m"');
    my $last_mon =  join(" ","date",'+"%Y-%m"',"-d",'"1 month ago"');
    my $last_year =  join(" ","date",'+"%Y"',"-d",'"1 month ago"');

    $this_mon = `$this_mon`;
    $last_mon = `$last_mon`;
    $last_mon =~ s/\n// ;
    $last_year = `$last_year`;
    $last_year =~ s/\n// ;
    my $work_dir = "/data/work/$last_year";

    my @month = ($this_mon,$last_mon,$last_year,$work_dir);
    return @month;
}

sub parse_log_compress{
    my @log = @_;
    my @month = &month_get();
    my $last_mon = $month[1];
    my $last_year = $month[2];
    my $work_dir = "/data/work/$last_year";

    foreach my $parse_log_file (@log) {
        if (-e $parse_log_file){
            Log_Text_Controls::error_log("****** start log compress $parse_log_file *******");
            system '/usr/bin/gzip', "$parse_log_file";
            if ($? != 0){ die "file compress error!! $parse_log_file"};
            Log_Text_Controls::error_log("****** end log compress $parse_log_file *******");
        } else {
            die Log_Text_Controls::error_log("****** $parse_log_file is missing *******");
        }
    }
}

sub apache_parse{
    my $line = $_[0];
    my $host = $_[1];

    if ($line !~ m/'HEAD|QuoteCheckServlet|WatchServlet|_Mod-Status|nagios|192.168.220'/){
        my @line  = split('"',$line);
        $line = join(" ",$line[0],$line[1],$line[2],$line[$#line]);
        $line =~ s/^- |192.168.210.2[0-9][0-9]|[0-9].* - - | - - | HTTP\/[0-9].[0-9]|\[|\]|\+0900|\n//g ;
        $line =~ s/,//g;
        $line =~ s/ +/,/g;
        $line = join(",", $line,"$host\n");
        return $line;
    }
}

sub coldfusion_parse{
    my $line = $_[0];
    my $host = $_[1];

    if ($line !~ m/'Severity|ThreadID|Date|Time|Application|Message|HEAD|QuoteCheckServlet|WatchServlet|_Mod-Status|nagios|192.168.220'/){
        my @line  = split(',,',$line);
        $line = $line[1];
        $line =~ s/"|http:\/\/127.0.0.1:8082|\n//g;
        my @tmp = split(',',$line);
        $tmp[3] =~ s/[^0-9].*//g;
        $line = join(',',@tmp,"$host\n");
        return $line;
    }
}


sub web_log_parser{
    my $server = $_[0];
    my @month = &month_get();
    my $last_mon = $month[1];
    my $last_year = $month[2];
    my $work_dir = $month[3];
    my @log;

    $server =~ s/\n//g ;
    Log_Text_Controls::error_log("***** start $server log parse ******");
    my $find_cmd;

        #nextとそれ以外を分けて処理
    if ($server =~ "appserver"){
        $find_cmd = join("","find /data/server -name cfProcessTime_",$last_mon,"-\*.zip |grep -e ",$server,"|sort");
    }else{
        $find_cmd = join("","find /data/server -name access_log.",$last_mon,"-\*.zip |grep -e ",$server,"|sort");
    }

    my @zip_list = `$find_cmd`;
    $server =~ s/\/ht\[0-1\]\[0-9\]\//ht/g;
    my $parse_log_file = join("","all_",$server,"_acccess_",$last_mon,".log");

    $parse_log_file = join("/",$work_dir,$server,$parse_log_file);

    if (!-d "$work_dir/$server"){
        mkdir "$work_dir/$server";
    }

    if (-e $parse_log_file) {
        open(OUT, ">$parse_log_file") || die "Can't Open '$parse_log_file' $!";
    }else{
        open(OUT, ">>$parse_log_file") || die "Can't Open '$parse_log_file' $!";
    }

   foreach my $log_file (@zip_list) {
        $log_file =~ s/\n//g;
        #nextとそれ以外を分けて処理
        my $host = $log_file;
        if ($host !~ "appserver"){
            $host =~ s/\/data\/server\/$server\/|\/httpd.*//g;
        }else{
            $host =~ s/\/data\/server\/$server\/|\/ColdFusion.*//g;
        }

        Log_Text_Controls::error_log("start log parse $log_file");
        open my $fh, "zcat $log_file 2>/dev/null |"
            || die "Can't zcat '$log_file' for reading: $!";
        while ( my $line = <$fh> ) {
            #nextとそれ以外を分けて処理
            if ($host =~ "appserver"){
                $line = &coldfusion_parse($line,$host);
            }else{
                $line = &apache_parse($line,$host);
            }
            print OUT $line;
        }
        close $fh || die "Can't close '$log_file' after reading: $!";
        Log_Text_Controls::error_log("end log parse $log_file");
    }
    close(OUT) || die "Can't close '$parse_log_file' after reading: $!";

    Log_Text_Controls::error_log("****** end log parse $server *******");

    return $parse_log_file;
}
