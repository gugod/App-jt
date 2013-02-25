package App::jt;
use Moo;
use MooX::Options;
use JSON;

option 'ugly' => (
    is => "ro",
    default => sub { 0 }
);

option 'pick' => (
    is => "ro",
    format => "i@",
    autosplit => ".."
);

option 'csv' => (
    is => "ro",
    default => sub { 0 }
);

option 'tsv' => (
    is => "ro",
    default => sub { 0 }
);

option 'fields' => (
    is => "ro",
    format => "s@"
);

option 'each' => (
    is => "ro",
    format => "s"
);

has data => ( is => "rw" );

sub run {
    my ($self) = @_;
    binmode STDIN => ":utf8";
    binmode STDOUT => ":utf8";

    my $text = do { local $/; <STDIN> };
    $self->data(JSON::from_json($text));
    print STDOUT JSON::to_json( $self->transform->data, { pretty => !($self->ugly) });
}

sub transform {
    my ($self, $data) = @_;

    if ($self->pick) {
        my ($m, $n) = @{$self->pick};
        if (defined($m) && defined($n)) {
            @{$self->data} = @{ $self->data }[ $m..$n ];
        }
        elsif (defined($m)) {
            my $len = scalar @{ $self->data };
            my @wanted = map { rand($len) } 1..$m;
            @{$self->data} = @{ $self->data }[ @wanted ];
        }
    }

    return $self;
}

1;

__END__

jt - json transformer

    # prettyfied
    curl http://example.com/action.json | jt

    # uglified
    cat random.json | jt --ugly > random.min.json

    ## The following commands assemed the input is an array of hashes.

    # take only selected fields 
    cat cities.json | jt --field name,country,latlon

    # randomly pick 10 hashes
    cat cities.json | jt --pick 10

    # pick 10 hashes from position 100, and uglified the output
    cat cities.json | jt --pick 100..109 --ugly

    # filtered by code
    cat cities.json | jt --grep '$_{country} eq "us"' | jt --field name,latlon

    # convert to csv
    cat cities.json | jt --csv

    # .. or tsv (tab-seperated)
    cat cities.json | jt --tsv

    # Run a piece of code on each hash
    cat orders.json | jt --each 'say "$_{name} sub-total: " . $_{count} * $_{price}'

    cat orders.json | jt --map '...'
    cat orders.json | jt --reduce '...'
