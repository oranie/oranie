#!/usr/bin/perl

use DBI;
use strict;

my $host = $ARGV[0];
my $session_id = $ARGV[1];

my $db_name = "hogehoge";
my $db_user = "hogehoge";
my $db_id = "hogehoge";
my $db_pass = "hogehoge";


my $dbh = DBI->connect("dbi:Oracle:$host:1521/$dbname",'$db_user','$db_id');
my $sql =  ("
   SELECT machine ||','|| count(*) from gv\$session
   where inst_id = $session_id
   group by inst_id, machine
    order by inst_id, machine
   " );

my $sth = $dbh->prepare
 ("
 $sql 
 " );

$sth -> execute();

my %datas = ();
my $tmp;

while(my @ary = $sth->fetchrow){
    $tmp = "@ary";
    my ($host, $session) = split(/,/, $tmp);
    $datas{$host} = "$session";
}
$sth -> finish();
$dbh->disconnect();

my $total;
foreach my $key ( sort keys %datas ) {
    $total = $total + $datas{$key};
}
print "$total";

