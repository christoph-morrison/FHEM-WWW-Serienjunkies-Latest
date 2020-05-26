## no critic (CodeLayout::RequireTidyCode)
package FHEM::Debug;

use warnings;
use strict;
use Data::Dumper;
use English qw{-no_match_vars};

# non-core modules
use Readonly;
use Exporter::Easy (
    OK => [q{bark}, q{moan}, q{whisper}]
);


Readonly my $MOAN_LOG_LEVEL =>  3;
Readonly my $BARK_LOG_LEVEL =>  1;

sub bark {
    my $message = shift;
    ::Log($message, $BARK_LOG_LEVEL);
    return;
}

sub moan {
    my $message = shift;
    ::Log($message, $MOAN_LOG_LEVEL);
    return;
}

sub whisper {
    my $message = shift;
    ::Debug($message);
    return;
}

sub write_log {
    my $message = shift;
    return;
}


1;