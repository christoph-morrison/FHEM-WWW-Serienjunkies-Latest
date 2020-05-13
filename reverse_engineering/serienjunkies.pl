#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use JSON::MaybeXS qw{decode_json};
use Readonly;
use File::Slurp;
use Data::Dumper;
use v5.11;

my $source = q{latest.json};
my $json_data = File::Slurp::read_file($source);
my $latest;
my $eval_status = scalar eval { $latest = decode_json($json_data) };
print Dumper ({q{Eval status} => $eval_status}) if (!$eval_status);
# say Dumper %latest;
say Dumper(ref $latest);
my %data = %{$latest};

for my $date (keys %{$latest}) {
    say("Date: $date");

    for my $item (@{$latest->{$date}}) {

=for comment

    $item->{name}
    $item->{_media}->{...}
        slug        Serien-Name


=cut
        say qq[\t * <a href="https://serienjunkies.org/serie/$item->{_media}{slug}">$item->{name}</a>]
    }
}

## now we do have the json data, good exercise for BR