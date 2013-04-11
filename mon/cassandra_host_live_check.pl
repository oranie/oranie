#!/usr/bin/perl
#######################################################################################################

use strict;
use warnings;
use Data::Dumper;
use Cassandra::Lite;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

my $host;

GetOptions(
    "h=s" => \$host
);

eval{
    my $c = Cassandra::Lite->new(
        server_name => "$host", 
        keyspace => 'system');

    my $columnFamily = 'Versions';
    my $key = 'build';

    my $hash_r = $c->get($columnFamily, $key);

    #print Dumper($hash_r);
    my %hash = %$hash_r;
    print %hash;
};if($@){
    print "$host status NG!!!!!!";
    print "$@\n";
    exit 2;
}
print "$host status OK!!"
exit 0;
