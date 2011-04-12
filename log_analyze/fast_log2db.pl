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


my $file_channel_id = Log_DB_Controls::create_channel_id($d,$u,$p,$file);

error_log("start");
open_gz_to_db($file, $file_channel_id);

sub error_log{
    my @log = @_;
    open(OUT, ">/tmp/sql_error.log");
    print OUT "@log\n";
    close(OUT);    
}

sub open_gz_to_db{
    my $file_name = shift or die "No File!! $!";
    my $channel_id = shift or die "No Channel ID!! $!";;
    my $sql_head = "INSERT INTO log_data(datetime,method,log_data,parametor,response_code,response_size,response_time,channel_id) value ";

    my @tmp = ();
    my $i = 0;

    open my $fh, "zcat $file_name 2>/dev/null |"
        or die "Can't zcat '$file_name' for reading: $!";
    while ( my $line = <$fh> ) {
        chomp $line;
        my $sql = Log_Text_Controls::create_insert_sql($line,$channel_id);

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

    close $fh
        or die "Can't close '$file_name' after reading: $!";
}

