#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Parallel::ForkManager;
use Log::Minimal;
use Data::Dumper;
use Cassandra::Lite;

#connect host ip
my $host;
#seq no
my $no;
#get or put 
my $method;
#keyspace
my $ks = "Keyspace1";
#column family
my $cf = "test_table";
#base key
my $key_name;

GetOptions(
    "h=s" => \$host,
    "n=i" => \$no,
    "m=s" => \$method,
    "k=s" => \$key_name,
);

sub make_test_key_name{
    my $base_text = $_[0];
    my $counter = $_[1];
    my $test_key_name = "$base_text$counter";
    return $test_key_name;
}

sub get_cassandra_data{
    my $host = $_[0];
    my $ks = $_[1];
    my $cf = $_[2];
    my $key_name = $_[3];

    my $c = Cassandra::Lite->new(
        server_name => "$host", 
        keyspace => "$ks");

    my $columnFamily = "$cf";
    my $hash_r;
    #infof("set data: $columnFamily, $key_name,");

    eval{
        $hash_r = $c->get($columnFamily, $key_name)
            or die;
    };if($@){
        die critf("get NG!! $columnFamily, $key_name,");
    }

    return $hash_r;
}

sub print_cassandra_data{
    my $hash_r = $_[0];
    my $key_name = $_[1];

    my %hash = %$hash_r;
    if(%hash){
        print "key = $key_name ";
        foreach my $key ( keys( %hash ) ) {
            print "column { $key : $hash{$key} }";
        }
        print ";\n" ;
    }else{
        print "key = $key_name : NO DATA ";
        print ";\n" ;
        die;
    }
}

sub put_cassandra_data{
    my $host = $_[0];
    my $ks = $_[1];
    my $cf = $_[2];
    my $key_name = $_[3];

    my $c = Cassandra::Lite->new(
        server_name => "$host", 
        keyspace => "$ks");

    my $columnFamily = "$cf";
    eval{
        $c->put($columnFamily, $key_name, {title => 'megaten',kansou => 'omoshiroi'});
        infof("$columnFamily, $key_name");
    };if($@){
        die critf("put NG!! $columnFamily, $key_name,");        
    }
    
}

sub print_get_data{
    my $host = $_[0];
    my $ks = $_[1];
    my $cf = $_[2];
    my $key_name = $_[3];
    my $no = $_[4];

    my $get_hash_r = get_cassandra_data($host,$ks,$cf,$key_name,$no);
    print_cassandra_data($get_hash_r,$key_name);
}

eval{
    if($method eq "get"){
        for (my $i = 0;$i < $no;$i++){
            my $test_key_name = make_test_key_name($key_name,$i);
            print_get_data($host,$ks,$cf,$test_key_name);
        }
    }elsif($method eq "put"){
        for (my $i = 0;$i < $no;$i++){
            my $test_key_name = make_test_key_name($key_name,$i);
            put_cassandra_data($host,$ks,$cf,$test_key_name);
        }
    }
};if($@){
    critf("$host status NG!!!!!!");
    critf("$@");
    exit 2;
}
infof("$host status OK!!");
exit 0;

=begin 
           # Insert it.
           $c->put($columnFamily, $key, {title => 'testing title', body => '...'});

       And get data:

           # Get a column
           my $scalarValue = $c->get($columnFamily, $key, 'title');

           # Get all columns
           my $hashRef = $c->get($columnFamily, $key);
=end COMMENT

=cut
