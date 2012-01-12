#!/usr/bin/env perl

use strict;
use warnings;
use Net::Telnet;
use Getopt::Long;

my %option = ();
my $help_msg = <<EOF
"-ho [host(:must)] -u [user(:must)] -p [password(:must)] -w [warning threshold %(:must)]\n
-c [critical threshold %(:must)]  --help or -h => PRINT HELP MESSAGE\n
example: telnet_check_disk.pl -ho 192.168.0.2 -u root -p hogehoge -w 60 -c 90"
EOF
;

GetOptions(\%option, 'host=s', 'password=s','user=s','warnings=i','critical=i','help');
if (defined $option{help} and $option{help} == 1){
        print $help_msg;
        exit(0);
}
$option{user}     ||= "root";
$option{password} ||= "hogehoge";
$option{warnings} ||= 80;
$option{critical} ||= 90;

my $host_name = $option{host};
my $user_name = $option{user};
my $password = $option{password};

my $warning_threshold  = $option{warnings};
my $critical_threshold = $option{critical};


eval{
    my @cmd_result = telnet_connect();

    my @parse_result = df_parse(@cmd_result);
    reslut_check(@parse_result);
    print "All Disk Used threshold OK!!!";
    exit 0;
};
if($@){
    print "check error!!! $@\n\n";
    exit 2;
}

sub df_parse{
    my @df = @_;

    my (@df_value,@warnings,@critical) = ();

    foreach my $line(@df){
        if ($line =~ /\/dev\// ){
            chomp($line);
            @df_value = split(' ',$line);
            my $used = $df_value[3] ;

            $used =~ s/%//;
            if ($used > $critical_threshold){
                push(@critical,"Critical!! $line\n");
            }elsif($used > $warning_threshold) {
                push(@warnings,"Warning!!  $line\n");
            }else{
                #push(@result, "Status OK !!!\n");
            }
        }
    }
    my @result = (
        \@critical,
        \@warnings
    );
    return @result;

}

sub reslut_check{
    my @result =  @_;
    my $critical_ref = $result[0];
    my $warnings_ref = $result[1];
    my @critical = @$critical_ref;
    my @warnings = @$warnings_ref;

    if( scalar(@critical) > 0 ){
        print "@critical @warnings";
        exit 2;
    }

    if( scalar(@warnings) > 0 ){
        print "@warnings";
        exit 1;
    }

    return 0;
}


sub telnet_connect{
    my $telnet = new Net::Telnet();
    # ホストに接続
    $telnet->open($host_name) or die "Telnet Open Error!!";
    # ログイン
    $telnet->login($user_name, $password) or die "Telnet Login Error!!";
    # コマンド実行 コマンド結果を標準出力
    my @result = $telnet->cmd("df") or die "Telnet cmd execute Error!!";
    # 接続を閉じる
    $telnet->close or die "telnet Close Error!!";

    return @result;
}


