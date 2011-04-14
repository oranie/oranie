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

eval{
    get_channel_info_from_file($d,$u,$p,$file);
};
if($@){
    Log_Text_Controls::error_log($@);
}

sub get_channel_info_from_file{
    my $d = $_[0];
    my $u = $_[1];
    my $p = $_[2];
    my $file = $_[3];

    # データベースへ接続
    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";
    my $sth;
    open my $fh, "<$file"
        or die "Can't read '$file' for reading: $!";

    while ( my $line = <$fh> ) {
        $sth = $dbh->prepare($line) or die "sql execute error $! \n $line\n";
        $sth->execute  or die "sql execute error $! \n $line\n";
    }

    $sth->finish  or die "DB Connection Close error $!" ;
    $dbh->disconnect;

}

