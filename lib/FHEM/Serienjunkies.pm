package FHEM::Serienjunkies;

use strict;
use warnings FATAL => 'all';
use JSON::MaybeXS qw{decode_json};
use Readonly;
use File::Slurp;
use Data::Dumper;
use FHEM::Meta;
use v5.11;

our $VERSION;

sub Initialize {

    my $device_definition = shift;

    $device_definition->{DefFn}         = \&handle_define;
    $device_definition->{UndefFn}       = \&handle_undefine;
    $device_definition->{SetFn}         = \&handle_set;
    $device_definition->{GetFn}         = \&handle_get;
    $device_definition->{AttrFn}        = \&handle_attributes;
    # $device_definition->{FW_detailFn}   = \&fhemweb_detail;

    return FHEM::Meta::InitMod( __FILE__, $device_definition );
}

############################################################ FHEM API

sub handle_define {

}

sub handle_undefine {

}

sub handle_set {

}

sub handle_get {

}

sub handle_attributes {

}

############################################################ stuff

1;