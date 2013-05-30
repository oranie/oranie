#!/usr/bin/perl
=begin 
cassandraに対してシーケンシャルにkeyを生成してputかgetをします。
keyspaceとcolumn familyはスクリプト内に書いているので、必要に応じて変更して下さい

-h ホストIP
-k ベースとなるkey名
-n 何件までやるか
-m getかputか
-l consistency_levelはQUORMかONEか

putする場合
perl ./cassandra_test_data.pl -h 127.0.0.1 -k megaten -n 1000000 -m put
この場合、megaten0というからスタートしてmegaten9999999まで順番にputします。
columは「key_name => "$key_name",title => 'megaten',kansou => 'omoshiroi'」で
key_nameだけ動的に生成したkeyをそのまま入れて残りは固定です

getする場合
perl ./cassandra_test_data.pl -h 127.0.0.1 -k megaten -n 1000000 -m get
この場合は取得するkeyの生成はputと同じで順番にgetします。

put/get共にエラーが出たらそこで処理を止めるようにしています。

=end
=cut

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
#base key name text
my $key_name;
#read/write consistency_level
my $level = "QUORUM";
#my $level = "ONE";

GetOptions(
    "h=s" => \$host,
    "n=i" => \$no,
    "m=s" => \$method,
    "k=s" => \$key_name,
    "l=s" => \$level,
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
    my $base_key_name = $_[3];
    my $seq_no = $_[4];

    my $c = Cassandra::Lite->new(
        server_name => "$host", 
        keyspace => "$ks",
        consistency_level_read => "$level",
        consistency_level_write => "$level");

    my $columnFamily = "$cf";
    my $hash_r;
    my $test_key_name;
    infof("set data: $columnFamily, $key_name,");

    eval{
        for (my $i = 0;$i < $seq_no;$i++){
            $test_key_name = make_test_key_name($base_key_name,$i);
            $hash_r = $c->get($columnFamily, $test_key_name)
                or die;
            print_cassandra_data($hash_r,$test_key_name);
        }
    };if($@){
        die critf("get NG!! $columnFamily, $test_key_name,");
    }

    return 0;
}

sub print_cassandra_data{
    my $hash_r = $_[0];
    my $key_name = $_[1];

    my %hash = %$hash_r;
    if(%hash){
        print "GET OK!! key = $key_name ";
        foreach my $key ( keys( %hash ) ) {
            print "column { $key : $hash{$key} }";
        }
        print ";\n" ;
    }else{
        print "NG!!! key = $key_name : NO DATA ;\n";
        die;
    }
}

sub put_cassandra_data{
    my $host = $_[0];
    my $ks = $_[1];
    my $cf = $_[2];
    my $base_key_name = $_[3];
    my $seq_no = $_[4];

    my $c = Cassandra::Lite->new(
        server_name => "$host", 
        keyspace => "$ks",
        consistency_level_read => "$level",
        consistency_level_write => "$level");

    my $columnFamily = "$cf";
    my $test_key_name;
    eval{
	    for (my $i = 0;$i < $seq_no;$i++){
            $test_key_name = make_test_key_name($base_key_name,$i);
            $c->put($columnFamily, $test_key_name, {key_name => "$test_key_name",title => 'megaten',kansou => 'omoshiroi'});
            infof("PUT OK!! $columnFamily, $test_key_name {key_name => \"$test_key_name\",title => 'megaten',kansou => 'omoshiroi'}");
        }
    };if($@){
        die critf("put NG!! $columnFamily, $test_key_name,");        
    }
    
}

eval{
    if($method eq "get"){
        get_cassandra_data($host,$ks,$cf,$key_name,$no);
    }elsif($method eq "put"){
        put_cassandra_data($host,$ks,$cf,$key_name,$no);
    }else{
        critf("$method is option error");
        die;
    }

};if($@){
    critf("$host status NG!!!!!!");
    critf("$@");
    exit 2;
}
infof("$host status OK!!");
exit 0;

=begin 
time perl ./cassandra_test_data.pl -h 127.0.0.1 -k megaten -n 1000000 -m get



           Cassandra::Lite memo

           # Insert it.
           $c->put($columnFamily, $key, {title => 'testing title', body => '...'});

       And get data:

           # Get a column
           my $scalarValue = $c->get($columnFamily, $key, 'title');

           # Get all columns
           my $hashRef = $c->get($columnFamily, $key);
=end COMMENT

=cut
