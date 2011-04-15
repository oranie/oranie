#!/usr/bin/perl

package Log_Text_Controls;

use strict;
use warnings;
use HTTP::Date;
use Math::Round;

sub error_log{
    my @log = @_;
    my $now_time = HTTP::Date::time2iso();
    open(OUT, ">>/tmp/fast_log2db.log");
    print OUT "$now_time  : @log\n";
    close(OUT);
}
 

#読み込んだ行を元にINSERT文のvalue部分を作成します。

sub create_insert_sql{
    my $log_line = shift;
    my $channel_id = shift;

    my $c = ($log_line =~ s/,/,/g);
    if ($c != 6 ){
        error_log("[Crit] log parse error!!!!! log_line : $log_line\n");
        return 1;
    }
 
    my %log_hash = ();
    ($log_hash{date}, $log_hash{method}, $log_hash{resource}, $log_hash{response_code}, 
        $log_hash{response_size}, $log_hash{response_time}, $log_hash{hostname} ) = split(/,/, $log_line) ;


    #リクエストにパラメータがある場合分割する。
    $log_hash{parametor} = "";
    if ( $log_hash{resource} =~ m/\?/){
        ($log_hash{resource}, $log_hash{parametor}) = split(/\?/, $log_hash{resource});
    }

    if ( $log_hash{response_size} =~ m/-/){
        $log_hash{response_size} = 0;
    }

    #マイクロ秒からミリ秒への丸め処理    
    $log_hash{response_time} = nearest(1000, $log_hash{response_time}) / 1000 ;

    #もしアクセスしたリソースが空だったら空文字で定義
    if (!defined $log_hash{resource}){
        &error_log($log_line);
        $log_hash{resource} = "";
    }

    if ($log_hash{response_code} !~ /^[0-9]{1,}$/ ){
        &error_log("[Crit] log parse error!!!!! response_code : $log_hash{response_code} :: $log_line\n");
        return 1;
    }

    if ($log_hash{response_size} !~ /^[0-9]{1,}$/ ){
        &error_log( "[Crit] log parse error!!!!! response_size : $log_hash{response_size} :: $log_line\n");
        return 1;
    }

    if ($log_hash{response_time} !~ /^[0-9]{1,}$|^-[0-9]{1,}$/ ){
        &error_log("[Crit] log parse error!!!!! response_time : $log_hash{response_time} :: $log_line\n");
        return 1;
    }

    #apache logの日付をMySQLのDATETIME型に合わせる
    $log_hash{date} = HTTP::Date::time2iso(str2time($log_hash{date}));
    my @sql_array = ($log_hash{date}, $log_hash{method}, $log_hash{resource},
        $log_hash{parametor}, $log_hash{response_code}, $log_hash{response_size}, $log_hash{response_time},$log_hash{hostname}, $channel_id,) ;

    my $sql2 = join( "','", @sql_array);
    $sql2 = "('$sql2')";
    return $sql2;
}


sub get_log_date{
    my $file_name = shift or die "No File!! $!";

    open my $fh, "zcat $file_name 2>/dev/null |"
        or die "Can't zcat '$file_name' for reading: $!";

    my $line = <$fh>;
    my %log_hash = ();
    ($log_hash{date}, $log_hash{method}, $log_hash{resource}, $log_hash{response_code},
        $log_hash{response_size}, $log_hash{response_time}, $log_hash{hostname}) = split(/,/, $line) ;
    my $date = HTTP::Date::time2iso(str2time($log_hash{date}));
    my @date = split(/\-/, $date);
    $date = join('', $date[0],$date[1]);
    return $date

}

return 1;

