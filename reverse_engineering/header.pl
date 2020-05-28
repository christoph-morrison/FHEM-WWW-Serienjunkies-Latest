#!/usr/bin/perl
use warnings FATAL => 'all';
use strict;
use Data::Dumper;
use Text::CSV;
use Text::Trim;
use v5.14;

my $header = qq{HTTP/1.1 200 OK
Date: Wed, 27 May 2020 20:24:55 GMT
Content-Type: application/json; charset=utf-8
Connection: close
Set-Cookie: __cfduid=d56ff39d880f48aa43f355e62b77168131590611094; expires=Fri, 26-Jun-20 20:24:54 GMT; path=/; domain=.serienjunkies.org; HttpOnly; SameSite=Lax
X-Powered-By: Express
ETag: frobnicate/"25a384-983zP42Jf9G/NR+Udcyh4uI+D8k"
CF-Cache-Status: DYNAMIC
cf-request-id: 02f968453e0000cdbfa68ea200000001
Expect-CT: max-age=604800, report-uri="https://report-uri.cloudflare.com/cdn-cgi/beacon/expect-ct"
Server: cloudflare
CF-RAY: 59a2764ec989cdbf-CDG
Content-Encoding: gzip};

 # $header = q{Set-Cookie: __cfduid=d56ff39d880f48aa43f355e62b77168131590611094; expires=Fri, 26-Jun-20 20:24:54 GMT; path=/; domain=.serienjunkies.org; HttpOnly; SameSite=Lax};

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

say Dumper(parse_http_header($header));
