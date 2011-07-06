#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Date;
use IO::File;
use DBD::mysql;
use DBI;
use Config::Simple;

#Log_DB_Controlsパッケージの読み込み
require "./lib/log_db_control.pm";
require "./lib/log_text_control.pm";
require "./lib/log_mail_control.pm";

my $file = shift or die "No File!! $!";

my $cfgObj = new Config::Simple;
$cfgObj->read('./lib/config.pm');
my $cfg = $cfgObj->vars();
my $d = $cfg->{'database.db'};
my $u = $cfg->{'database.user'};
my $p = $cfg->{'database.password'};


eval{
    Log_Text_Controls::error_log("DB execute start $file");
    get_channel_info_from_file($file);
    Log_Text_Controls::error_log("DB execute end $file");
    Log_Mail_Controls::mail_send("end $file","on");
};
if($@){
    Log_Text_Controls::error_log($@);
    Log_Mail_Controls::mail_send("$@ $file","on");
}
 
sub get_channel_info_from_file{
    my $file = $_[0];

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

