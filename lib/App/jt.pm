package App::jt;
use Moo;
use MooX::Options;
use JSON;

option 'ugly' => (
    is => "ro",
    doc => "Produce uglyfied json output"
);

option 'pick' => (
    is => "ro",
    format => "i@",
    autosplit => "..",
    doc => "`--pick n`: Pick n objects randomly. `--pick n..m`: Pick object in this range."
);

option 'csv' => (
    is => "ro",
    default => sub { 0 },
    doc => "Produce csv output for scalar values."
);

option 'silent' => (
    is => "ro",
    doc => "Silent output."
);

# option 'fields' => (
#     is => "ro",
#     format => "s@"
# );

option 'map' => (
    is => "ro",
    format => "s",
    doc => "Run the specified code for each object, with %_ containing the object content."
);

has data => ( is => "rw" );

sub run {
    my ($self) = @_;
    binmode STDIN => ":utf8";
    binmode STDOUT => ":utf8";

    my $text = do { local $/; <STDIN> };
    $self->data(JSON::from_json($text));
    $self->transform;


    if ($self->csv) {
        $self->output_csv;
    }
    elsif (!$self->silent) {
        $self->output_json;
    }
}

sub output_json {
    my ($self) = @_;
    print STDOUT JSON::to_json( $self->data, { pretty => !($self->ugly) });
}

sub output_csv {
    require Text::CSV;

    my ($self) = @_;
    my $o = $self->data->[0] or return;
    my @keys = grep { !ref($o->{$_}) } keys %$o;

    my $csv = Text::CSV->new({ binary => 1 });
    $csv->combine(@keys);

    print STDOUT $csv->string() . "\n";
    for $o (@{ $self->{data} }) {
        $csv->combine(@{$o}{@keys});
        print STDOUT $csv->string() . "\n";
    }
}

sub transform {
    my ($self) = @_;

    if ($self->map) {
        my $code = $self->map;
        for my $o (@{ $self->data }) {
            local %_ = %$o;
            eval "$code";
            %$o = %_;
        }
    }
    elsif ($self->pick) {
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

    # convert to csv. Only scalar values are chosen.
    cat cities.json | jt --csv

    # Run a piece of code on each hash
    cat orders.json | jt --map 'say "$_{name} sub-total: " . $_{count} * $_{price}'

    cat orders.json | jt --reduce '...'
