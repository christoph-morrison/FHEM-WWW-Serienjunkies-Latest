## no critic (CodeLayout::RequireTidyCode)
package FHEM::WWW::Serienjunkies;

use strict;
use warnings FATAL => 'all';
use experimental qw( switch );
use JSON::MaybeXS qw{decode_json};
use Readonly;
use FHEM::Meta;
use FHEM::Debug qw{whisper};
use English qw{-no_match_vars};
use Data::Dumper;
use Time::Seconds;
use List::Util;
use 5.014;

Readonly our $VERSION                   => q{0.0.1};
Readonly our $DEFAULT_DATA_URI          => q{https://serienjunkies.org/api/releases/latest};
Readonly our $DEFAULT_REQUEST_INTERVAL  => 300;
Readonly our $DEFAULT_TIMEOUT           => 10;
Readonly our $DEFAULT_HTTP_METHOD       => q{GET};
Readonly our @VALID_INTERVALS           => qw{10 60 300 3600};

############################################################ handle_attributes
Readonly our %ATTRIBUTE_HANDLER         => (
    q{filter}   => {
        q{set} => sub {
            my $parameters = shift;
            set_request_timer($parameters->{device_name});
            return;
        },
        q{del} => sub {
            my $parameters = shift;
            set_request_timer($parameters->{device_name});
            return;
        },
    },
    q{interval} => {
        q{set} => sub {
            my $parameters = shift;
            return;
        },
        q{del} => sub {
            my $parameters = shift;
            return;
        },
    },
    q{disable}  => {
        q{set} => sub {
            my $parameters = shift;

            if ($parameters->{attribute_value} == 1) {
                disable_request_timer($parameters->{device_name});
                return;
            }

            if ($parameters->{attribute_value} == 0) {
                set_request_timer($parameters->{device_name});
                return;
            }
        },
        q{del} => sub {
            my $parameters = shift;

            set_request_timer($parameters->{device_name});
            return;
        },
    },
);

::Debug(Dumper(%ATTRIBUTE_HANDLER));

############################################################ FHEM API
sub initialize {

    my $device_definition = shift;

    $device_definition->{DefFn}         = \&handle_define;
    $device_definition->{UndefFn}       = \&handle_undefine;
    $device_definition->{SetFn}         = \&handle_set;
    $device_definition->{GetFn}         = \&handle_get;
    $device_definition->{AttrFn}        = \&handle_attributes;
    $device_definition->{AttrList}      = join(
            q{ },
            (
                q{filter:textField-long},
                q{disable:0,1},
                q{interval:} . join q{,}, @VALID_INTERVALS,
            )
        ) . qq[ $::readingFnAttributes ];

    return FHEM::Meta::InitMod( __FILE__, $device_definition );
}

sub handle_define {
    my $global_definition   = shift;
    my $define              = shift;

    if ( !FHEM::Meta::SetInternals($global_definition) ) {
        ::Debug($EVAL_ERROR);
        return $EVAL_ERROR;
    }

    Readonly my $ARG_INDEX_MIN_LENGTH   => 2;
    Readonly my $ARG_INDEX_NAME         => 0;

    my @define_arguments    = split m{ \s+ }xms, $define;
    my $device_name        = $define_arguments[$ARG_INDEX_NAME];

    if (scalar @define_arguments < $ARG_INDEX_MIN_LENGTH) {
        return q{Syntax: define <name> Serienjunkies};
    }

    $global_definition->{NAME}              = $device_name;
    $global_definition->{VERSION}           = $VERSION;
    $global_definition->{DEFAULT_URI}       = $DEFAULT_DATA_URI;
    $global_definition->{REQUEST_INTERVAL}  = $DEFAULT_REQUEST_INTERVAL;

    set_request_timer($device_name);

    return;
}

sub handle_undefine {
    return;
}

sub handle_set {
    return;
}

sub handle_get {
    return;
}

sub handle_attributes {
    my $verb                = shift;
    my $device_name         = shift;
    my $attribute_name      = shift;
    my $attribute_value     = shift;
    my $global_definition    = get_global_definition($device_name);

    whisper(Dumper({
        q{device_name}      =>  $device_name,
        q{verb}             =>  $verb,
        q{attribute_name}   =>  $attribute_name,
        q{attribute_value}  =>  $attribute_value,
    }));

    if (!List::Util::any { $verb eq $ARG } qw{ set del }) {
        return qq{[$device_name] Action '$verb' is neither set nor del.};
    }

    if (defined $ATTRIBUTE_HANDLER{$attribute_name}) {
        return &{$ATTRIBUTE_HANDLER{$attribute_name}{$verb}}(
            {
                q{device_name}      =>  $device_name,
                q{verb}             =>  $verb,
                q{attribute_name}   =>  $attribute_name,
                q{attribute_value}  =>  $attribute_value,
            }
        );
    }
}

############################################################ timer

sub set_request_timer {
    my $device_name = shift;
    my $global_definition = get_global_definition($device_name);

    # reset timer
    disable_request_timer($device_name);

    # update next update timestamp
    my $next_update = int(time() + $global_definition->{REQUEST_INTERVAL});

    # save information for the interested reader
    $global_definition->{NEXT_UPDATE_TS} = $next_update;
    $global_definition->{NEXT_UPDATE_HR} = localtime $next_update;

    # perform data update
    request_data($device_name);

    # define new timer
    ::InternalTimer( $next_update, \&set_request_timer, $device_name );

    return 1;
}

sub disable_request_timer {
    my $device_name = shift;
    my $global_definition = get_global_definition($device_name);

    ::RemoveInternalTimer( $global_definition, \&set_request_timer );
    # save information for the interested reader
    $global_definition->{NEXT_UPDATE_TS} = q{disabled};
    $global_definition->{NEXT_UPDATE_HR} = q{disabled};

    return;
}

sub request_data {
    my $device_name         = shift;
    my $global_definition    = get_global_definition($device_name);

    my $request_parameters  = {
        url             =>  $global_definition->{DEFAULT_URI},
        timeout         =>  $DEFAULT_TIMEOUT,
        device_name     =>  $device_name,
        method          =>  $DEFAULT_HTTP_METHOD,
        callback        =>  \&parse_response_data,
    };

    ::HttpUtils_NonblockingGet($request_parameters);

    return;
}

sub parse_response_data {
    my $request_params      =   shift;
    my $response_error      =   shift;
    my $response_data       =   shift;
    my $device_name         =   $request_params->{device_name};
    my $global_definition    =   get_global_definition($device_name);

    my $response_content;
    my $eval_status = eval { $response_content = JSON::MaybeXS::decode_json($response_data) };

    if ($EVAL_ERROR || !$eval_status) {
        #   todo Error handling in case the JSON could not be parsed
        whisper($EVAL_ERROR);
        whisper($eval_status);
    }

    # reset readings
    delete $global_definition->{READINGS};

    # create a reading for every item
    ::readingsBeginUpdate($global_definition);

    my @filter = split qr{ \s+ }xsm, ::AttrVal($device_name, q{filter}, q{});
    whisper(q{Filter: } . Dumper(@filter));

    my $found_items = 0;

    for my $publish_date (keys %{$response_content}) {
        whisper($publish_date);
        # create a reading for every item
        for my $published_item (@{$response_content->{$publish_date}}) {

            if (List::Util::any { $published_item->{name} =~ qr{$ARG}xsm } @filter) {
                whisper(qq{\t\t Found: } . $published_item->{name});
                ::readingsBulkUpdate($global_definition, $published_item->{id}, $published_item->{name});
                ++$found_items;
            }

        }
    }

    ::readingsBulkUpdate($global_definition, q{state}, $found_items);
    ::readingsEndUpdate( $global_definition, 1 );


    return;
}

############################################################ helper subroutines

## no critic (ProhibitPackageVars)
sub get_global_definition {
    my $device_name = shift;
    return $::defs{$device_name};
}
## use critic

1;