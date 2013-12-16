#!/usr/bin/perl

use strict;
use warnings;
use DBD::mysql;
use DBI;
use DBIx::QueryLog;
use Log::Minimal;
use Data::Dumper;

local $DBIx::QueryLog::OUTPUT = sub {
    my %args = @_;
    infof($args{sql});
};
local $Log::Minimal::LOG_LEVEL = "INFO";

my $database = "cacti_test";

my $d = "DBI:mysql:$database:127.0.0.1";
my $u = "root";
my $p = "";

my $base_domain = ".test.jp";
my $regexp_base = "s13-soc-sb-";
my $regexp_change = "sb-deka-soc-";

my $master_description = "";
my $master_hostname = "";
my $update_description = "";
my $update_hostname = "";

my $host_select_sql = 
    "select description,hostname from host;";
my $backup_table_create_sql = 
    "DROP TABLE IF EXISTS `host_test`;create table host_test LIKE host";
my $backup_data_insert_sql = 
    "INSERT INTO host_test (select * from host)";
my $host_update_sql = 
    "UPDATE host_test SET description=?,hostname=? WHERE description=? AND hostname=?;";


eval{
    create_backup($backup_table_create_sql,$backup_data_insert_sql);
    infof("DB execute start");
    get_and_update_hostname($host_select_sql);
    infof("DB execute end");
};if($@){
    critf("$@ DB COMMIT ERROR");
}

sub create_backup{
    my $backup_table_create_sql = $_[0];
    my $backup_data_insert_sql = $_[1];

    eval{
        my $dbh = DBI->connect($d, $u, $p)
            or die "DB Connect error $!";
        my $sth;
        infof("create host table backup start");
        $sth = $dbh->prepare($backup_table_create_sql) ;
        $sth->execute or die "sql execute error $DBI::errstr";
        $sth = $dbh->prepare($backup_data_insert_sql) ;
        $sth->execute or die "sql execute error $DBI::errstr";

        $sth->finish or die "DB Connection Close ERROR";
        $dbh->disconnect;
        infof("create host table backup complete!!!");

        return 0;        
    }; if($@){
        critf($@);
        return 1;
    }
}

sub get_and_update_hostname{
    my $sql = $_[0] or die "No Query!!!";

    eval{
        my $dbh = DBI->connect($d, $u, $p)
            or die "DB Connect error $!";
        my $sth;

        $sth = $dbh->prepare($sql) ;
        $sth->execute or die "sql execute error $DBI::errstr";
        while(my @row = $sth->fetchrow_array) {
            $master_description = $row[0];
            $master_hostname = $row[1];
            debugf("master data | description:$master_description\thostname:$master_hostname");
            $update_description = $master_description;
            $update_description =~ s/$regexp_base/$regexp_change/;
            $update_hostname = $update_description . $base_domain;

            my $update_sth = $dbh->prepare($host_update_sql);
            $update_sth->execute($update_description,$update_hostname,$master_description,$master_hostname)
                 or die "sql execute error $DBI::errstr";
            debugf("update data | description:$update_description\thostname:$update_hostname"); 
        }
        infof("DB execute OK!");
        $sth->finish or die "DB Connection Close ERROR" ;
        $dbh->disconnect;

        return 0;

    };if($@){
        critf($@);
        return 1;
    }
}

