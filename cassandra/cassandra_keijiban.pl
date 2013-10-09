use Amon2::Lite;
use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Parallel::ForkManager;
use Log::Minimal;
use Data::Dumper;
use Cassandra::Lite;
use Plack::Builder;

my $host = "127.0.0.1";
my $ks = "oranie";
my $cf = "keijiban";
my $level = "ONE";
my $base_key_name = "megaten";


post '/commit' => sub {
    my $amon = shift;
    #my $id = $amon->req->param('id');
    my $name = $amon->req->param('name');
    my $title = $amon->req->param('title');
    my $text = $amon->req->param('text');
    my $error;
    print "$name $title $text\n";
    unless ($name && $title && $text) {
        my $error = "項目全部入れてね";
        return $amon->create_response(404, [], ["$error"]);
    }
    my $id = get_counter();
    $id++;
    #$id = reset_counter();
    increment_counter();
    put_cassandra_data($id,$name,$title,$text);
    return $amon->redirect('/');
    #return $amon->create_response(200, [], ["POST OK"]);
};

get '/' => sub {
    my $amon = shift;

    my @hash_r_list = get_cassandra_data();
    my @result;
    my $form_html = form_html();
    push(@result,$form_html);
    my $i = 0;
    foreach my $hash_r (@hash_r_list){
        my $mojiretsu = "";
        for my $key (keys %$hash_r){
            my $text = "$key = " . $hash_r->{$key} . " ";
            $mojiretsu = $mojiretsu . $text . "\n</br>";
        }
        $mojiretsu = "No is $i</br>" . $mojiretsu . "\n</br>";
        push(@result,$mojiretsu);
        $i++;
    }
    return $amon->create_response(200, [], [@result]);
};


my $c = Cassandra::Lite->new(
        server_name => "$host", 
        keyspace => "$ks",
        consistency_level_read => "$level",
        consistency_level_write => "$level");

sub get_cassandra_data{
    my $columnFamily = "$cf";
    my $hash_r;
    my @hash_r_list;
    my $counter = get_counter();
    infof("counter is $counter");
    eval{
        for (my $id = 0;$id <= $counter;$id++){
            $hash_r = $c->get($columnFamily, $id)
                or die;
            push(@hash_r_list,$hash_r);
            print Dumper($hash_r);
        }
    };if($@){
        #die critf("Dumper($@) get NG!! $columnFamily, $test_key_name,");
        print Dumer($@);
        print Dumper(@hash_r_list);
        die @hash_r_list;
    }

    return @hash_r_list ;
}


sub put_cassandra_data{
    my $id = $_[0];
    my $name = $_[1];
    my $title = $_[2];
    my $text = $_[3];
    my $date = localtime();

    eval{
        $c->put($cf, $id, {name => "$name", title => "$title", text => "$text", date => "$date"});
        infof("PUT OK!! $cf, $id $name $title $date");
    };if($@){
        print Dumper($@);
        die critf("put NG!! $cf, $id ,Dumper($@)");        
    }
    return 0;    
}

sub get_counter{
    my $c = Cassandra::Lite->new(
        server_name => "$host",
        keyspace => "$ks",
        consistency_level_read => "$level",
        consistency_level_write => "$level");

    my $cf_counter = "counter";
    my $counter_key = "0";
    my $count;
    eval{
        my $counter_r = $c->get($cf_counter, $counter_key)
            or die;

        $count =  $counter_r->{id};
        infof("counter is $count");

    };if($@){
        print Dumper($@);
        exit;
    }
    return $count;
}

sub increment_counter{
    my $c = Cassandra::Lite->new(
        server_name => "$host",
        keyspace => "$ks",
        consistency_level_read => "$level",
        consistency_level_write => "$level");

    my $now_count = get_counter();
    my $inc_count = $now_count;
    $inc_count++;

    my $cf_counter = "counter";
    my $counter_key = "0";
    eval{
        $c->put($cf_counter, $counter_key, { id => "$inc_count"});
        infof("counter increment ok now $inc_count");
    };if($@){
        print Dumper($@);
    }
}

sub reset_counter{
    my $c = Cassandra::Lite->new(
        server_name => "$host",
        keyspace => "$ks",
        consistency_level_read => "$level",
        consistency_level_write => "$level");

    my $cf_counter = "counter";
    my $counter_key = "0";
    eval{
        $c->put($cf_counter, $counter_key, { id => "0"});
    };if($@){
        print Dumper($@);
    }
    return 0;
}

sub form_html{
my $text = <<'EOS';
<form action="/commit" method="post">
<p>
名前：<input type="text" name="name" size="40">
</p>
<p>
タイトル：<input type="text" name="title" size="40">
</p>
コメント：<br>
<textarea name="text" rows="4" cols="40"></textarea>
</p>
<p>
<input type="submit" value="送信">
</p>
</form> 
EOS

return $text;
}

__PACKAGE__->to_app();
