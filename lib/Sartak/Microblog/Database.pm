package Sartak::Microblog::Database;
use 5.14.0;
use Moose;
use DBI;

use Sartak::Microblog::Post;
use Sartak::Microblog::Feed;

has file => (
    reader   => '_file',
    isa      => 'Str',
    required => 1,
);

has dbh => (
    reader  => '_dbh',
    lazy    => 1,
    builder => '_build_dbh',
    handles => {
        _prepare => 'prepare',
        _do      => 'do',
    },
);

sub _build_dbh {
    my $self = shift;
    my $needs_schema = !-e $self->_file;

    my $dbh = DBI->connect("dbi:SQLite:dbname=" . $self->_file);
    $dbh->{sqlite_unicode} = 1;

    if ($needs_schema) {
        $self->schematize($dbh);
    }

    return $dbh;
}

sub schematize {
    my $self = shift;
    my $dbh  = shift;

    $dbh->do(<< '    SCHEMA');
CREATE TABLE posts (
    id TEXT PRIMARY KEY,
    created INTEGER,
    text TEXT NOT NULL,
    language TEXT,
    cruft TEXT
);
    SCHEMA
}

sub insert_post {
    my $self = shift;
    my $post = shift;

    my $ok = $self->_do("INSERT INTO posts (id, created, text, language, cruft) values (?, ?, ?, ?, ?);", {},
        $post->id,
        $post->created,
        $post->text,
        $post->language,
        $post->cruft,
    );
    return $ok;
}

sub feed {
    my $self = shift;
    my %args = @_;

    my $query = "SELECT id, created, text, language FROM posts ";
    my @bind;

    if ($args{language}) {
        $query .= "WHERE language=? ";
        push @bind, $args{language};
    }

    $query .= "ORDER BY created DESC ";
    $query .= "LIMIT 20 ";
    $query .= ";";

    my $sth = $self->_prepare($query);
    $sth->execute(@bind);

    my @posts;
    while (my ($id, $created, $text, $language) = $sth->fetchrow_array) {
        my $post = Sartak::Microblog::Post->new(
            id       => $id,
            text     => $text,
            language => $language,
            created  => $created,
        );
        push @posts, $post;
    }

    return Sartak::Microblog::Feed->new(
        title => $args{title},
        posts => \@posts,
    );
}

sub post {
    my $self = shift;
    my $id   = shift;

    my $query = "SELECT id, created, text, language FROM posts WHERE id=?;";
    my @bind = ($id);

    my $sth = $self->_prepare($query);
    $sth->execute(@bind);

    my @posts;
    if (my ($id, $created, $text, $language) = $sth->fetchrow_array) {
        my $post = Sartak::Microblog::Post->new(
            id       => $id,
            text     => $text,
            language => $language,
            created  => $created,
        );
        return $post;
    }

    return;
}

sub update_post {
    my $self = shift;
    my $post = shift;
    my $cols = shift;

    my $query = "UPDATE posts SET ";
    my @bind;

    for my $col (keys %$cols) {
        $query .= "$col=? ";
        push @bind, $cols->{$col};
    }

    $query .= "WHERE id=?;";
    push @bind, $post->id;

    my $ok = $self->_do($query, {}, @bind);
    return $ok;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

