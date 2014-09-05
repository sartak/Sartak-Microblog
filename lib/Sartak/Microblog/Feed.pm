package Sartak::Microblog::Feed;
use 5.14.0;
use Moose;

use Sartak::Microblog::Post;

has title => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has posts => (
    traits   => ['Array'],
    reader   => 'posts_ref',
    isa      => 'ArrayRef[Sartak::Microblog::Post]',
    required => 1,
    handles  => {
        posts    => 'elements',
        add_post => 'push',
    },
);

sub as_rss {
    my $self = shift;

    use XML::RSS;
    use Encode 'decode_utf8';

    my $feed = XML::RSS->new(version => '1.0');
    $feed->channel(
        title => $self->title,
        link  => 'http://micro.sartak.org',
    );

    for my $post ($self->posts) {
        $feed->add_item(
            title       => $post->text,
            link        => "http://micro.sartak.org/post/" . $post->created,
            description => $post->text,
            dc          => {
                date    => $post->feed_date,
                author  => 'Shawn M Moore',
            },
        );
    };

    return $feed->as_string;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

