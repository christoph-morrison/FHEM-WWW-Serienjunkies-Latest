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
use Digest::MD5;
use Text::CSV;
use Text::Trim;
use HTTP::Headers::Util;
use Storable;
use 5.014;

Readonly our $VERSION                   => q{0.0.1};
Readonly our $DEFAULT_DATA_URI          => q{https://serienjunkies.org/api/releases/latest};
Readonly our $DEFAULT_REQUEST_INTERVAL  => 300;
Readonly our $DEFAULT_TIMEOUT           => 10;
Readonly our $DEFAULT_HTTP_METHOD       => q{GET};
Readonly our $DEFAULT_FILTER            => q{};
Readonly our $VALID_FILTER_LANGUAGES    => {
    q{DE} => q{GERMAN},
    q{EN} => q{ENGLISH},
};
Readonly our $DEFAULT_FILTER_LANGUAGE   => q{DE};
Readonly our @VALID_INTERVALS           => qw{10 60 300 3600};

############################################################ handle
Readonly our %ATTRIBUTES  => (
    q{interval}              => {
        q{set} => sub {
            my $parameters = shift;

            if (!List::Util::any {$parameters->{attribute_value} == $ARG} @VALID_INTERVALS) {
                return qq[$parameters->{attribute_value} is not a valid interval. Choose one of @VALID_INTERVALS];
            }

            # update request interval, set new timer
            $parameters->{global_definition}->{REQUEST_INTERVAL} = $parameters->{attribute_value};
            set_request_timer($parameters->{device_name});

            return;
        },
        q{del} => sub {
            my $parameters = shift;
            $parameters->{REQUEST_INTERVAL} = $DEFAULT_REQUEST_INTERVAL;
            set_request_timer($parameters->{device_name});
            return;
        },
        q{def} => join(q{,}, @VALID_INTERVALS),
    },
    q{disable}               => {
        q{def} => q{0,1},
        q{set} => sub {
            my $parameters = shift;

            if ($parameters->{attribute_value} == 1) {
                disable_device($parameters->{device_name});
                return;
            }

            if ($parameters->{attribute_value} == 0) {
                enable_device($parameters->{device_name});
                return;
            }
        },
        q{del} => sub {
            my $parameters = shift;
            enable_device($parameters->{device_name});
            return;
        },
    },
    q{filter_name}           => {
        q{set}   => sub {
            my $parameters = shift;
            set_request_timer($parameters->{device_name});
            return;
        },
        q{del}   => sub {
            my $parameters = shift;
            set_request_timer($parameters->{device_name});
            return;
        },
        q{get}   => sub {
            my $parameters = shift;
            return ::AttrVal($parameters->{device_name}, q{filter_name}, undef);
        },
        q{apply} => sub {
            my $parameters = shift;
            return;

        },
        q{def}   => q{textField-long},
    },
    q{filter_language}       => {
        q{set} => sub {
            my $parameters = shift;
            if (!List::Util::any {$parameters->{attribute_value} eq $ARG} keys %{$VALID_FILTER_LANGUAGES}) {
                return q{Non-valid value for language_filter};
            }
            set_request_timer($parameters->{device_name});
            return;
        },
        q{del} => sub {
            my $parameters = shift;
            set_request_timer($parameters->{device_name});
            return;
        },
        q{def} => join q{,}, keys %{$VALID_FILTER_LANGUAGES},
    },
    q{disable-content-cache} => {
        q{def}   => q{0,1},
        q{set}   => sub {
            #todo checks
            return;
        },
        q{del}   => sub {
            #todo checks
            return;
        },
        q{apply} => sub {
            # todo
            return;
        },
    },
    q{disable-request-cache} => {
        q{def}   => q{0,1},
        q{set}   => sub {
            #todo checks
            return;
        },
        q{del}   => sub {
            #todo checks
            return;
        },
        q{apply} => sub {
            # todo
            return;
        },
    },
);

############################################################ FHEM API
sub initialize {

    my $device_definition = shift;

    $device_definition->{DefFn}         = \&handle_define;
    $device_definition->{UndefFn}       = \&handle_undefine;
    $device_definition->{SetFn}         = \&handle_set;
    $device_definition->{GetFn}         = \&handle_get;
    $device_definition->{AttrFn}        = \&handle_attributes;
    $device_definition->{AttrList}      = get_attributes({
        q{attributes}         => \%ATTRIBUTES,
        q{default_attributes} => 1,
    });

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
    $global_definition->{CONTENT_DIGEST}    = q{null};
    $global_definition->{ETag}              = q{null};
    $global_definition->{LAST_MODIFIED}     = q{};

    whisper(join q{,}, keys %{$VALID_FILTER_LANGUAGES});

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

sub get_attributes {
    my ($attributes_ref) = @ARG;
    my @attributes;

    for my $attribute (keys %{$attributes_ref->{attributes}}) {
        whisper(Dumper($attributes_ref->{attributes}->{$attribute}));

        if (defined $attributes_ref->{attributes}->{$attribute}->{def}) {
            push(@attributes, join q{:}, ($attribute, $attributes_ref->{attributes}->{$attribute}->{def}));
        } else {
            push(@attributes, qq{$attribute:noArg});
        }
    }

    push(@attributes, $::readingFnAttributes) if $attributes_ref->{default_attributes};

    whisper(Dumper(\@attributes));

    return join q{ }, @attributes;
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

    if (defined $ATTRIBUTES{$attribute_name}) {
        return &{$ATTRIBUTES{$attribute_name}{$verb}}(
            {
                q{global_definition}    =>  $global_definition,
                q{device_name}          =>  $device_name,
                q{verb}                 =>  $verb,
                q{attribute_name}       =>  $attribute_name,
                q{attribute_value}      =>  $attribute_value,
            }
        );
    }
}

############################################################ timer

sub set_request_timer {
    my $device_name = shift;
    my $interval = shift;
    my $global_definition = get_global_definition($device_name);

    # reset timer
    disable_request_timer($device_name);

    if ($global_definition->{REQUEST_INTERVAL} eq q{disabled}) {
        whisper(q{Update is disabled, stop request});
        return;
    }

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
    $global_definition->{NEXT_UPDATE_TS}    = q{disabled};
    $global_definition->{NEXT_UPDATE_HR}    = q{disabled};

    return;
}

sub request_data {
    my $device_name         = shift;
    my $global_definition   = get_global_definition($device_name);

    # build additional headers
    # It's ok if no additional header is set
    my @additional_headers = ();

    # add If-None-Match if ETag is set and the request cache was not disabled by attribute
    my $force_update = ::AttrVal($device_name, q{disable-request-cache}, undef);
    if (!$force_update && defined $global_definition->{ETag}) {
        push(@additional_headers, qq[If-None-Match: "$global_definition->{ETag}"]);
    }

    my $request_parameters  = {
        url             =>  $global_definition->{DEFAULT_URI},
        timeout         =>  $DEFAULT_TIMEOUT,
        device_name     =>  $device_name,
        method          =>  $DEFAULT_HTTP_METHOD,
        callback        =>  \&parse_response_data,
        header          =>  join qq[\r\n], @additional_headers
    };

    ::HttpUtils_NonblockingGet($request_parameters);

    return;
}

sub parse_response_data {
    my $request_params      =   shift;
    my $response_error      =   shift;
    my $response_data       =   shift;
    my $device_name         =   $request_params->{device_name};
    my $global_definition   =   get_global_definition($device_name);
    my $response_content;
    my $force_update        = ::AttrVal($device_name, q{disable-content-cache}, undef);

    if ($request_params->{code} == 304) {
        ::readingsSingleUpdate($global_definition, q{state}, q{not modified}, 1);
        whisper(Dumper({
            q{message}      => q{If Non-Match said content was not modified. Skipping.},
            q{force?}       => $force_update,
            q{raw}          => $request_params->{httpheader},
        }));
        return;
    }


    my $headers_ref = undef;
    if (defined $request_params->{httpheader}) {
        $headers_ref = parse_http_header($request_params->{httpheader});
        $global_definition->{ETag} = $headers_ref->{ETag}{id} if (defined $headers_ref->{ETag}{id});
    }

    whisper(Dumper(\{
        q{title}  => q{HTTP headers parsed:},
        q{values} => Dumper($headers_ref),
        q{raw}    => $request_params->{httpheader},
    }));

    my $md5sum = Digest::MD5::md5_hex($response_data);

    if (!$force_update && $md5sum eq $global_definition->{CONTENT_DIGEST}) {
        ::readingsSingleUpdate($global_definition, q{state}, q{not modified}, 1);

        whisper(Dumper({
            q{message}      => q{Content was not modified. Skipping.},
            q{old md5}      => $global_definition->{CONTENT_DIGEST},
            q{request md5}  => $md5sum,
            q{force?}       => $force_update,
        }));
        return;
    }



    $global_definition->{LAST_MODIFIED} = localtime time;
    $global_definition->{CONTENT_DIGEST} = $md5sum;

    my $eval_status = eval { $response_content = JSON::MaybeXS::decode_json($response_data) };

    # seed filter language with the default value: every language
    my $filter_language = q{.*};
    if (::AttrVal($device_name, q{filter_language}, undef)) {
        $filter_language = ::AttrVal($device_name, q{filter_language}, $DEFAULT_FILTER_LANGUAGE);
        $filter_language = lc $VALID_FILTER_LANGUAGES->{$filter_language};
    }
    my $filter_language_re = qr{$filter_language}xims;

    whisper($filter_language);


    my @filter = split qr{ \s+ }xsm, ::AttrVal($device_name, q{filter_name}, (q{.*}));

    if ($EVAL_ERROR || !$eval_status) {
        #   todo Error handling in case the JSON could not be parsed
        whisper($EVAL_ERROR);
        whisper($eval_status);
    }

    # reset readings
    delete $global_definition->{READINGS};

    # create a reading for every item
    ::readingsBeginUpdate($global_definition);

    my $found_items = 0;

    for my $publish_date (keys %{$response_content}) {
        whisper($publish_date);
        # create a reading for every item
        for my $published_item (@{$response_content->{$publish_date}}) {

            if (List::Util::any { $published_item->{name} =~ qr{$ARG}xsm } @filter) {
                whisper(qq{\t\t Found: } . $published_item->{name});

                # skip if a language filter is set and the language does not match
                if ($filter_language && $published_item->{language} !~ $filter_language_re ) {
                    next;
                }

                # update reading
                ::readingsBulkUpdate($global_definition, $published_item->{id}, $published_item->{name});
                ++$found_items;
            }

        }
    }

    ::readingsBulkUpdate($global_definition, q{state}, $found_items);
    ::readingsEndUpdate( $global_definition, 1 );


    return;
}

sub parse_http_header {
    my $header = shift;
    my %headers;
    my @fields;

    # http header are separated line by line with [\r\n]
    my @header_lines = split qr{[\r\n]+}, $header;

    my $header_split_re = qr{
        ^(?<name>[^\s:]+)   # The name of a http header line is always like "foobar:" at the start of a line, ...
            :\s*                # separated by : and additional but optional whitespaces
            (?<fields>.+)$      # The fields are the rest of the line and can contain anything but [\r\n] - they are matched by $
    }xms;

    # for splitting the header lines into fields, we need a ; as separator
    my $csv_line = Text::CSV->new({
        sep_char    => q{;},
        quote_char  => q{'},
        escape_char => undef,
    }) or die(Text::CSV->error_diag());

    # for splitting the fields into sub-fields / particles, we need the = as separator
    my $csv_field = Text::CSV->new({
        sep_char           => q{=},
        quote_char         => q{'},
        escape_char        => undef,
        allow_loose_quotes => 1,
    }) or die(Text::CSV->error_diag());

    for my $line (@header_lines) {
        # split into name and field
        if ($line =~ $header_split_re) {
            my ($name, $fields) = ($+{name}, $+{fields});

            if ($csv_line->parse($fields)) {

                # parse the line into single fields - at this level, fields in a line are separated by semicolon
                @fields = $csv_line->fields();

                # some fields come with unnecessary whitespaces at the beginning or end, strip them recursively
                Text::Trim::trim(@fields);

                # if more than one field found, split the fields by =, because that's the (possible) separator for
                # html fields, but there also single word fields like HttpOnly for Set-Cookie - these are
                # saved with as key with an undefined value instead of the field value
                if (scalar @fields > 1) {
                    for my $sub_field (@fields) {
                        $csv_field->parse($sub_field);
                        my @subfields = $csv_field->fields();
                        $headers{$name}{$subfields[0]} = $subfields[1];
                    }

                    # skip the handling because the token is already saved to the return value
                    next;
                }

                # ETag needs a special handling, because it's supports an additional information in the field,
                # separated by / from the quoted, real ETag id
                # This additional information is a [Ww] and identifies the ETag as "weak", if the information
                # is not supplied, it's considered a strong ETag
                # https://en.wikipedia.org/wiki/HTTP_ETag
                if (lc $name eq q{etag}) {
                    $fields[0] =~ qr{^(?<weakness>[Ww]{1})?/?(?<quote>["'])?(?<etag_id>.*)\g{quote}$};
                    my $weakness = $+{weakness} // 0;
                    my $id       = $+{etag_id}  // undef;

                    # canonize $weakness to 0 or 1
                    if ($weakness) {
                        $weakness = (lc $weakness eq q{w}) ? 1 : 0;
                    }

                    # if the ETag is not weak, the whole field value is the ETag id
                    # might be an error but ¯\_(ツ)_/¯
                    if (!$weakness) {
                        $id = $fields[0];
                    }

                    # save and go to next header line
                    $headers{$name} = {
                        q{weakness}    => $weakness,
                        q{id}           => $id,
                    };
                    next;
                }

                # single field, simply add it to the return
                $headers{$name} = $fields[0];
            }
        }
    }

    return \%headers;
}


############################################################ helper subroutines
sub disable_device {
    my ($device_name) = @ARG;
    my $global_definition = get_global_definition($device_name);

    # don't do any further requests
    disable_request_timer($device_name);

    # update interal state, set STATE to inactive for IsDisabled() support
    $global_definition->{REQUEST_INTERVAL} = q{disabled};
    ::readingsSingleUpdate($global_definition, q{state}, q{inactive}, 1);

    return;
}

sub enable_device {
    my ($device_name) = @ARG;
    my $global_definition = get_global_definition($device_name);

    # update internal save request intveral
    $global_definition->{REQUEST_INTERVAL} =
        ::AttrVal($device_name, q{interval}, $DEFAULT_REQUEST_INTERVAL);

    # restart internal timer
    set_request_timer($device_name);
    return;
}

## no critic (ProhibitPackageVars)
sub get_global_definition {
    my $device_name = shift;
    return $::defs{$device_name};
}
## use critic

1;