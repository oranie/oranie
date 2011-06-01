#!/usr/bin/perl

package Log_Mail_Controls;

use strict;
use warnings;
use utf8;
use Encode;
use Email::MIME;
use Email::MIME::Creator;
use Email::Send;
use IO::All;

sub mail_send{
    my $body = $_[0];
    my $file = $_[1];
    if ($file =~ m/on/){
        $file = '/tmp/log2db.log';
        $file = io($file)->all;
    }

    my @parts = (
         Email::MIME->create(
            'attributes' => {
            'content_type' => 'text/plain',
            'charset'     => 'ISO-2022-JP',
            'encoding'    => '7bit',
            },
            'body' => Encode::encode( 'iso-2022-jp', $body ),
        ),
         Email::MIME->create(
            'attributes' => {
            'content_type' => 'text/plain',
            'charset'     => 'ISO-2022-JP',
            'encoding'    => '7bit',
            },
            'body' => Encode::encode( 'iso-2022-jp', $file ),
        )
    );

    my $mail = Email::MIME->create(
        header => [
            From    => 'root@example.com',
            To      => 'test@example.co.jp',
            Subject => Encode::encode('MIME-Header-ISO_2022_JP', 'バッチ処理速報'),
        ],
        parts => [@parts],
    );

    my $sender = Email::Send->new({mailer => 'Sendmail'});
    $sender->send($mail);
}


return 1;
