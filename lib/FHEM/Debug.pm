## no critic (CodeLayout::RequireTidyCode)
package FHEM::Debug;

use warnings;
use strict;
use Readonly;
use Data::Dumper;
use English qw{-no_match_vars};
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(bark moan whisper);


Readonly my $MOAN_LOG_LEVEL =>  3;
Readonly my $BARK_LOG_LEVEL =>  1;

sub bark {
    my $message = shift;
    ::Log($message, $BARK_LOG_LEVEL);
}

sub moan {
    my $message = shift;
    ::Log($message, $MOAN_LOG_LEVEL);
}

sub whisper {
    my $message = shift;
    ::Debug($message);
}

sub write_log {
    my $message = shift;
}


1;