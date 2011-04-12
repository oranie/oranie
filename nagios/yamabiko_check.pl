#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket;
use Getopt::Long;
use HTTP::Date;

my $time_diff = 10;
my $alarm_timer = 5;
my %config = ();
my $help_msg = "-ho [host(:must)] -p [port(:must)] -s [send_message] -r [recive message] --HELP or -H => PRINT HELP MESSAGE  \n";

GetOptions(\%config, 'host=s', 'port=i', 'send_msg=s','rcv_msg=s','HELP');

if (defined $config{HELP} and  $config{HELP} == 1){
        print $help_msg;
        exit(0);
}
$config{send_msg} ||= "HELLO SERVER\n";
$config{rcv_msg} ||= "OK\n";

die "$help_msg \n " unless defined $config{host} and $config{port};


sub time_check {
    my $server_time = $_[0] ;
    my $timer = $_[1];
    my $now_time  = str2time(localtime());
    my $result = abs($now_time - $server_time);
    print "Time diff = $result sec\n";
    if ( $result <= $timer ){
        print "Server Response Time OK !!!\n";
        return (0);
    }
    else {
        die "Server Reponce Time NG !!!!\n";
    }
}

sub status_check {
    my $server_status = $_[0] ;
    my $check_char  = $_[1] ;

    if ( $server_status =~ /$check_char/){
        print "Server Response OK !! \n";
        return (0);
    }
    else {
        die "Server Response NG !!!! \n";
    }
}

sub connect_test {
    my $host = $_[0] ;
    my $port = $_[1] ;
    my $send = $_[2] ;
    my $rcv  = $_[3] ;
    my $alarm_timer =$_[4] ;
    my $sock = new IO::Socket::INET(
            PeerAddr=> $host,
            PeerPort=> $port,
            Proto=>'tcp',
            TimeOut  => 5);
    die ("IO::Socket : $!") unless $sock;
    print $sock "$send\n";
    print "Client RECV START\n";
    my $tmp = 0;
    eval {
        local $SIG{ALRM} = sub { die "Server Response Timeout" };   
        alarm $alarm_timer;
        $tmp = <$sock>;
        alarm 0;
        close($sock);
    };
    if ($@) {
        die $@;
    }
    return $tmp;
    return (0);
}

eval{
    my $server_response = &connect_test($config{host},$config{port},$config{send_msg},$config{rcv_msg},$alarm_timer);
    print "SERVER RESPONSE :  $server_response\n";
    $server_response =~ s/"//gimx;
    my($response_time, $response_status) = split(/,/, $server_response);
    &time_check($response_time , $time_diff );
    &status_check($response_status , $config{rcv_msg});
    exit (0);
    };
if( $@ ){
    print "$@\n";
    exit (2);
}

