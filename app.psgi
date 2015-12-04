#!/usr/bin/env perl
use utf8;
use 5.14.0;
use warnings;

# Xslate with Moose seems to spend a LOT of time cloning objects
BEGIN { $ENV{ANY_MOOSE} = 'Mouse' }

use Plack::Builder;
use Sartak::Microblog::Database;
use Encode 'encode_utf8';
use Text::Handlebars;
use Text::Xslate 'mark_raw';
use Text::Markdown 'markdown';
use HTML::Escape 'escape_html';
use Plack::App::File;

# Regexp::Common doesn't support #fragments
# http://d.hatena.ne.jp/sugyan/20100903/1283451850
use Regexp::Common 'URI';
my $hex      = q<[0-9A-Fa-f]>;
my $escaped  = qq<%$hex$hex>;
my $uric     = q<(?:[-_.!~*'()a-zA-Z0-9;/?:@&=+$,]> . qq<|$escaped)>;
my $fragment = qq<$uric*>;
my $punct    = qq<[.,!?]>;
my $re_uri   = qr[($RE{URI}(?:\#$fragment)?(?<!$punct))];

my %is_image = (
    '.png' => 1,
    '.gif' => 1,
    '.jpg' => 1,
);
sub is_image { $is_image{shift()} }

sub linkify {
    my $link = shift;
    my ($ext) = $link =~ /\.(\w+)$/;

    if (is_image($ext)) {
        return qq[<a href="$link"><img src="$link" /></a>];
    }
    else {
        return qq[<a href="$link">$link</a>];
    }
}

my $db = Sartak::Microblog::Database->new(file => 'posts.sqlite');
my $hbs = Text::Handlebars->new(
    path    => ['view'],
    cache   => $ENV{XSLATE_CACHE_LEVEL},
    helpers => {
        format_date => sub {
            my ($context, $epoch, $format) = @_;
            use DateTime;
            return DateTime->from_epoch(epoch => $epoch)->strftime($format);
        },
        format_post_text => sub {
            my ($context, $text) = @_;

            $text =~ s/\n/\n\n/g;
            $text = markdown(escape_html($text));
            $text =~ s{$re_uri}{linkify($1)}eg;
            $text =~ s{@(\w+)}{<a href="https://twitter.com/$1">\@$1</a>}g;

            return mark_raw($text);
        },
    },
);

builder {
    mount '/favicon.ico' => sub {
        return [
            302,
            ['Location' => 'http://sartak.org/favicon.ico'],
            [''],
        ];
    };

    mount '/static/' => Plack::App::File->new(root => "view/static/")->to_app;

    mount '/feed/micro.rss' => sub {
        my $feed = $db->feed(title => "sartak's microblog");
        return [
            200,
            ['Content-Type' => 'application/rss+xml'],
            [ $feed->as_rss ],
        ];
    };

    mount '/feed/en.rss' => sub {
        my $feed = $db->feed(language => 'en', title => "sartak's english microblog");
        return [
            200,
            ['Content-Type' => 'application/rss+xml'],
            [ $feed->as_rss ],
        ];
    };

    mount '/feed/ja.rss' => sub {
        my $feed = $db->feed(language => 'ja', title => 'sartakのミニブログ');
        return [
            200,
            ['Content-Type' => 'application/rss+xml'],
            [ $feed->as_rss ],
        ];
    };

    mount '/post/' => sub {
        my $env = shift;
        if ($env->{PATH_INFO} =~ m{^/(\d+)$}) {
            my $post = $db->post($1);
            if ($post) {
                return [
                    200,
                    ['Content-Type' => 'text/html'],
                    [ encode_utf8 $hbs->render('post', { post => $post }) ],
                ];
            }
        }

        return [
            404,
            [],
            ['Not found'],
        ];
    };

    mount '/' => sub {
        my $env = shift;

        if ($env->{PATH_INFO} eq '/') {
            my $feed = $db->feed(title => "sartak's microblog");
            return [
                200,
                ['Content-Type' => 'text/html'],
                [ encode_utf8 $hbs->render('feed', { feed => $feed }) ],
            ];
        }

        # if ($env->{PATH_INFO} eq '') {
        #     return [
        #         200,
        #         ['Content-Type' => 'text/plain'],
        #         [ '' ],
        #     ];
        # }

        return [
            404,
            [],
            ['Not found'],
        ];
    };

};

