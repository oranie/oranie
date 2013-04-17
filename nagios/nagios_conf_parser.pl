#!perl

use strict;
use warnings;
use Data::Dumper;
use JSON;

my $nagios_conf_dir;

my $host_file_path = "/etc/nagios/Default_collector/hosts.cfg";
my $hostgroup_file_path = "/etc/nagios/Default_collector/hostgroups.cfg";

my $host_regexp = 'host_name|address';
my $hostgroup_regexp = 'hostgroup_name|members';

sub make_cmd{
    my $file = $_[0];
    my $regexp = $_[1];

    my $cmd = "cat $file | egrep '$regexp' | awk \'{print \$1,\":\",\$2}\'| sed -e \'s/ *//g\' ";

    return $cmd;
}
my $parse_host_cmd = make_cmd($host_file_path,$host_regexp);
my $parse_hostgroup_cmd = make_cmd($hostgroup_file_path,$hostgroup_regexp);

my @parse_host_list = qx{$parse_host_cmd};
my @parse_hostgroup_list = qx{$parse_hostgroup_cmd};


sub host_list_to_hash{
    my @host_list = @_;
    my %host_hash;
    my @host_name;
    my @host_address;

    eval{
        foreach my $line (@host_list){
        chomp($line);
            if ($line =~ "host_name"){
                @host_name = split(/:/,$line);
        next;
            }
        elsif($line =~ "address"){
        @host_address = split(/:/,$line);
        }
        else{
        next ;
        };
        $host_hash{"$host_name[1]"} = "$host_address[1]";
        }
    };if($@){
        print "$@";
        return 1;
    }
    return %host_hash ;
}

sub group_list_to_hash{
    my @hostgroup_list = @_;
    my %hostgroup_hash;
    my @hostgroup_name;
    my @hostgroup_members;

    eval{
        foreach my $line (@hostgroup_list){
            chomp($line);
            if ($line =~ "hostgroup_name"){
                @hostgroup_name = split(/:/,$line);
                next;
            }
            elsif($line =~ "members"){
                @hostgroup_members = split(/:/,$line);
            }
            else{
                next ;
            };
        my @members = split(/,/,$hostgroup_members[1]);
            $hostgroup_hash{"$hostgroup_name[1]"} = "@members";
        }
    };if($@){
        print "$@";
        return 1;
    }
    return %hostgroup_hash ;
}

my %group_hash = group_list_to_hash(@parse_hostgroup_list);
my %host_hash = host_list_to_hash(@parse_host_list);
my $host_json = \%host_hash;
my $group_json = \%group_hash;
print to_json($host_json);
print "\n";
print to_json($group_json);

#foreach my $key ( sort keys %ghash ){
#    print "$key:$ghash{$key}\n";
#}

[narita_takashi@s13-soc-op-rs-ds-obs01p ~]$ cat ./nagios_conf_parser.pl 
#!perl

use strict;
use warnings;
use Data::Dumper;
use JSON;

my $nagios_conf_dir;

my $host_file_path = "/etc/nagios/Default_collector/hosts.cfg";
my $hostgroup_file_path = "/etc/nagios/Default_collector/hostgroups.cfg";

my $host_regexp = 'host_name|address';
my $hostgroup_regexp = 'hostgroup_name|members';

sub make_cmd{
    my $file = $_[0];
    my $regexp = $_[1];

    my $cmd = "cat $file | egrep '$regexp' | awk \'{print \$1,\":\",\$2}\'| sed -e \'s/ *//g\' ";

    return $cmd;
}
my $parse_host_cmd = make_cmd($host_file_path,$host_regexp);
my $parse_hostgroup_cmd = make_cmd($hostgroup_file_path,$hostgroup_regexp);

my @parse_host_list = qx{$parse_host_cmd};
my @parse_hostgroup_list = qx{$parse_hostgroup_cmd};


sub host_list_to_hash{
    my @host_list = @_;
    my %host_hash;
    my @host_name;
    my @host_address;

    eval{
        foreach my $line (@host_list){
        chomp($line);
            if ($line =~ "host_name"){
                @host_name = split(/:/,$line);
        next;
            }
        elsif($line =~ "address"){
        @host_address = split(/:/,$line);
        }
        else{
        next ;
        };
        $host_hash{"$host_name[1]"} = "$host_address[1]";
        }
    };if($@){
        print "$@";
        return 1;
    }
    return %host_hash ;
}

sub group_list_to_hash{
    my @hostgroup_list = @_;
    my %hostgroup_hash;
    my @hostgroup_name;
    my @hostgroup_members;

    eval{
        foreach my $line (@hostgroup_list){
            chomp($line);
            if ($line =~ "hostgroup_name"){
                @hostgroup_name = split(/:/,$line);
                next;
            }
            elsif($line =~ "members"){
                @hostgroup_members = split(/:/,$line);
            }
            else{
                next ;
            };
        my @members = split(/,/,$hostgroup_members[1]);
            $hostgroup_hash{"$hostgroup_name[1]"} = "@members";
        }
    };if($@){
        print "$@";
        return 1;
    }
    return %hostgroup_hash ;
}

my %group_hash = group_list_to_hash(@parse_hostgroup_list);
my %host_hash = host_list_to_hash(@parse_host_list);
my $host_json = \%host_hash;
my $group_json = \%group_hash;
print to_json($host_json);
print "\n";
print to_json($group_json);

#foreach my $key ( sort keys %ghash ){
#    print "$key:$ghash{$key}\n";
#}

