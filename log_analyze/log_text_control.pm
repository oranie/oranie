#!/usr/bin/perl

package Log_Text_Controls;

use strict;
use warnings;
use HTTP::Date;

sub create_insert_sql{
    my $log_line = shift;
    my $channel_id = shift;

    my %log_hash = ();
    ($log_hash{date}, $log_hash{method}, $log_hash{resource}, $log_hash{response_code}, $log_hash{response_size}, $log_hash{response_time}) = split(/,/, $log_line) ;

    if (!defined $log_hash{resource}){
    error_log($log_line);
        $log_hash{resource} = "";
    }

    $log_hash{parametor} = "";
    if ( $log_hash{resource} =~ m/\?/){
        ($log_hash{resource}, $log_hash{parametor}) = split(/\?/, $log_hash{resource});
    }

    if ( $log_hash{response_size} =~ m/-/){
        $log_hash{response_size} = 0;
    }

    $log_hash{date} = HTTP::Date::time2iso(str2time($log_hash{date}));
    my @sql_array = ($log_hash{date}, $log_hash{method}, $log_hash{resource}, $log_hash{parametor}, $log_hash{response_code}, $log_hash{response_size}, $log_hash{response_time}, $channel_id) ;

    my $sql2 = join( "','", @sql_array);
    $sql2 = "('$sql2')";
    return $sql2;
}


return 1;

