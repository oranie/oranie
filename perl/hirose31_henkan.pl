#シュワルツ変換サンプル
#!/usr/bin/perl
use strict;
use warnings;

my @list = qw(れい いち に さん し ご ろく なな はち きゅう とお);
my $base = 3;

my $i    = 0;
my @sorted_surplus = map { $_->[0] }
                     sort { $a->[1]%$base <=> $b->[1]%$base }
                     map { [$_, $i++] } @list;
print "$_\n" for @sorted_surplus;

