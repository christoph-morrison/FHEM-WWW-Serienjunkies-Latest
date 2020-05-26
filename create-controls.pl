#!/usr/bin/perl

use warnings FATAL => 'all';
use File::Basename;
use POSIX qw(strftime);
use strict;

my @filenames = qw{
    lib/FHEM/WWW/Serienjunkies.pm
    lib/FHEM/Debug.pm
    FHEM/98_Serienjunkies.pm
};

my $filename = "";
foreach $filename (@filenames)
{
    my @statOutput = stat($filename);

    if (scalar @statOutput != 13)
    {
        printf("error: stat has unexpected return value for $filename.\n");
        next;
    }

    my $mtime = $statOutput[9];
    my $date = POSIX::strftime("%Y-%m-%d", localtime($mtime));
    my $time = POSIX::strftime("%H:%M:%S", localtime($mtime));
    my $filetime = $date."_".$time;

    my $filesize = $statOutput[7];

    printf("UPD $filetime $filesize $filename\n");
}
