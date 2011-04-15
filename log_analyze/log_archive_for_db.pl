#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Date;
use IO::File;
use File::Find;

#Log_DB_Controlsパッケージの読み込み
require "./log_db_control.pm";
require "./log_text_control.pm";

my @channel = ("hogehoge","fugafuga");

eval{
    Log_Text_Controls::error_log("------------------------------START ALL LOG PARSE");
    my @tmp = &apache_log_parser("@channel");
    &parse_log_compress(@tmp);
    Log_Text_Controls::error_log("------------------------------FINISH ALL LOG PARSE");
};
if($@){
    Log_Text_Controls::error_log("[Crit] : $@");
}

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

sub apache_log_parser{
    my @chnnel = @_;
    my @month = &month_get();
    my $last_mon = $month[1];
    my $last_year = $month[2];
    my $work_dir = $month[3];
    my @log;

    foreach my $server (@channel) {
        $server =~ s/\n//g ;
        Log_Text_Controls::error_log("***** start $server log parse ******");

        my $find_cmd = join("","find /data/server -name access_log.",$last_mon,"-\*.zip |grep -e ",$server,"|sort");
        my @zip_list = `$find_cmd`;
        $server =~ s/\/ht\[0-1\]\[0-9\]\//ht/g;
        my $parse_log_file = join("","all_",$server,"_acccess_",$last_mon,".log");

        $parse_log_file = join("/",$work_dir,$server,$parse_log_file);

        if (!-d "$work_dir/$server"){
            mkdir "$work_dir/$server";
        }

        if (-e $parse_log_file) {
            open(OUT, ">$parse_log_file") 
                or die "Can't Open '$parse_log_file' $!";
        }else{
            open(OUT, ">>$parse_log_file") 
                or die "Can't Open '$parse_log_file' $!";
        }

        foreach my $log_file (@zip_list) {
            $log_file =~ s/\n//g;
            my $host = $log_file;
            $host =~ s/\/data\/server\/$server\/|\/httpd.*//g;
            Log_Text_Controls::error_log("start log parse $log_file");
            open my $fh, "zcat $log_file 2>/dev/null |"
                or die "Can't zcat '$log_file' for reading: $!";
            while ( my $line = <$fh> ) {
                if ($line !~ m/'HEAD|QuoteCheckServlet|WatchServlet|_Mod-Status|nagios|192.168.220'/){
                    my @line  = split('"',$line);
                    $line = join(" ",$line[0],$line[1],$line[2],$line[$#line]);
                    $line =~ s/^- |192.168.210.2[0-9][0-9]|[0-9].* - - | HTTP\/[0-9].[0-9]|\[|\]|\+0900|\n//g ;
                    $line =~ s/,//g;
                    $line =~ s/ +/,/g;
                    $line = join(",", $line,"$host\n");
                    print OUT "$line";
                }               
            }
            close $fh
                or die "Can't close '$log_file' after reading: $!";
            Log_Text_Controls::error_log("end log parse $log_file");
        }
        close(OUT)
            or die "Can't close '$parse_log_file' after reading: $!";

        Log_Text_Controls::error_log("****** end log parse $server *******");
        push(@log,$parse_log_file);
    }
    return @log;
}


