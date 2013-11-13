#use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

for (my $i = 0 ; $i < 40000;$i++){
    my $FH = "FH" . "$i" . "test";
    open $FH, ">${i}.filename.txt";
    sleep 1;
}
print "FH execute end!!\n";
sleep 300;
print "script end!!\n";
