#!/usr/bin/perl

package Log_DB_Controls;

use strict;
use warnings;
use HTTP::Date;

sub create_table_sql{
    my $file_name = shift or die "No File!! $!";

    open my $fh, "zcat $file_name 2>/dev/null |"
        or die "Can't zcat '$file_name' for reading: $!";

    my $line = <$fh>;
    my %log_hash = ();
    ($log_hash{date}, $log_hash{method}, $log_hash{resource}, $log_hash{response_code}, $log_hash{response_size}, $log_hash{response_time}) = split(/,/, $line) ;
    my $date = HTTP::Date::time2iso(str2time($log_hash{date}));
    my @date = split(/\-/, $date);
    $date = join('', $date[0],$date[1]);

    my $create_table_name = "log_data_$date";

    my $create_table_sql = <<"EOF";
        DROP TABLE IF EXISTS `$create_table_name`;
        SET \@saved_cs_client     = \@\@character_set_client;
        SET character_set_client = utf8;
        CREATE TABLE `$create_table_name` (
           `log_id` int(11) unsigned NOT NULL auto_increment,
           `datetime` datetime NOT NULL,
           `method` varchar(20) NOT NULL,
           `log_data` text NOT NULL,
           `parametor` text,
           `response_code` smallint(5) unsigned NOT NULL,
           `response_size` int(11) unsigned NOT NULL,
           `response_time` int(11) unsigned NOT NULL,
           `channel_id` int(11) unsigned NOT NULL,
       PRIMARY KEY  (`log_id`),
       UNIQUE KEY `log_id` (`log_id`),
       KEY `channel_id` (`channel_id`)
     ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ;
EOF
    return $create_table_sql;
}

sub create_channel_id{
    my $sql = "select channel_id,channel_name from MASTER_CHANNEL";
    my $d = shift;
    my $u = shift;
    my $p = shift;
    my $file = shift;

    my $chanel_id = 0;
    my $name = "";

    my $dbh = DBI->connect($d, $u, $p)
        or die "DB Connect error $!";

    my $sth = $dbh->prepare("$sql") or die "sql execute error $!";
    $sth->execute  or die "sql execute error $!";
    my %hash = ();
    while (my @ary = $sth->fetchrow_array()){
        my ($no , $name) = @ary;
        $hash{$name} = $no;
    }
    $sth->finish  or die "DB Connection Close error $!" ;
    $dbh->disconnect;

    foreach  my $chanel_name (keys %hash){
        if ( $file =~ $chanel_name ){
            $chanel_id = $hash{$chanel_name};
            $name = $chanel_name;
            last;
        }
    }
    return $chanel_id;
}

return 1;
