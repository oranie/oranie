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

my $host_select_sql = "select description,hostname from host;";
my $host_update_sql = "UPDATE host_test SET description=?,hostname=? WHERE description=? AND hostname=?;";


eval{
    infof("DB execute start");
    get_and_update_hostname($host_select_sql);
    infof("DB execute end");
};if($@){
    critf("$@ DB COMMIT ERROR");
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
            infof("master data | description:$master_description\thostname:$master_hostname");
            $update_description = $master_description;
            $update_description =~ s/$regexp_base/$regexp_change/;
            $update_hostname = $update_description . $base_domain;

            my $update_sth = $dbh->prepare($host_update_sql);
            $update_sth->execute($update_description,$update_hostname,$master_description,$master_hostname)
                 or die "sql execute error $DBI::errstr";
            infof("update data | description:$update_description\thostname:$update_hostname"); 
        }
        infof("DB execute OK!");
        $sth->finish or die "DB Connection Close ERROR" ;
        $dbh->disconnect;
    };if($@){
        critf($@);
    }
    return 0;
}

