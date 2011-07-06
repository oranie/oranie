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

return 1 

