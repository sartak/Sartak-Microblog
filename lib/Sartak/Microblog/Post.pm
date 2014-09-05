package Sartak::Microblog::Post;
use 5.14.0;
use Moose;

has id => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has text => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has created => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has language => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has cruft => (
    is            => 'ro',
    isa           => 'Str',
    documentation => 'arbitrary metadata. e.g. when importing from Twitter, this holds all the information Twitter provided, for posterity',
);

sub feed_date {
    my $self = shift;

    use DateTime;
    my $dt = DateTime->from_epoch(epoch => $self->created);

    return $dt->strftime('%a, %d %b %Y %T %Z');
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

