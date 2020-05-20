## no critic

use lib q{./lib};
use warnings FATAL => 'all';
use strict;
use FHEM::WWW::Serienjunkies;
use GPUtils;
use English q{-no_match_vars};

sub Serienjunkies_Initialize {
    return FHEM::WWW::Serienjunkies::initialize(@ARG);
}

1;

