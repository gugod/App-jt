#!/usr/bin/env perl

use strict;

use Test::More;
use IO::String;
use App::jt;

subtest "--ugly" => sub {
    my $in  = <<'IN';
{
     "a" : 41,
     "b" : 42
}
IN
    my $out = "";

    App::jt->new(
        input_handle  => IO::String->new($in),
        output_handle => IO::String->new($out),
        "ugly"        => 1
    )->run;

    is $out, qq<{"a":41,"b":42}\n>;
};

subtest "default behaviour (prettify)" => sub {
    my $in  = q!{a:41,"b":42}!;
    my $out = "";

    App::jt->new(
        input_handle  => IO::String->new($in),
        output_handle => IO::String->new($out)
    )->run;

    is $out, <<'OUT';
{
   "a" : 41,
   "b" : 42
}
OUT

};

subtest "uglify" => sub {
    my $in  = q!{a:41,"b":42}!;
    my $out = "";

    App::jt->new(
        input_handle  => IO::String->new($in),
        output_handle => IO::String->new($out),
        ugly => 1
    )->run;

    is $out, <<'OUT';
{"a":41,"b":42}
OUT

};

subtest "silent" => sub {
    my $in  = q!{a:41,"b":42}!;
    my $out = "";

    App::jt->new(
        input_handle  => IO::String->new($in),
        output_handle => IO::String->new($out),
        silent => 1
    )->run;

    is $out, "";
};

done_testing;
