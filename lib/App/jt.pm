package App::jt;
use Moo;
use MooX::Options;
use JSON -support_by_pp;
use IO::Handle;
use Hash::Flatten qw(flatten unflatten);
use List::MoreUtils qw(any);

has output_handle => (
    is => "ro",
    default => sub {
        my $io = IO::Handle->new;
        $io->fdopen( fileno(STDOUT), "w");
        binmode $io, ":utf8";
        return $io;
    }
);

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

option 'tsv' => (
    is => "ro",
    default => sub { 0 },
    doc => "Produce csv output for scalar values."
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

option 'fields' => (
    is => "ro",
    format => "s@",
    autosplit => ",",
    doc => "Filter the input to contain only these fields."
);

option 'output_flatten' => (
    is => "ro",
    default => sub { 0 },
    doc => "Produce flatten output."
);

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

    my $json_decoder = JSON->new;
    $json_decoder->allow_singlequote(1)->allow_barekey(1);

    my $text = do { local $/; <STDIN> };
    $self->data( $json_decoder->decode($text) );
    $self->transform;

    if ($self->csv) {
        $self->output_csv;
    }
    elsif ($self->tsv) {
        $self->output_tsv;
    }
    elsif (!$self->silent) {
        $self->output_json;
    }
}

sub out {
    my ($self, $x) = @_;
    $x ||= "";
    $x .= "\n" unless substr($x, -1, 1) eq "\n";
    $self->output_handle->print($x);
}

sub output_json {
    my ($self) = @_;
    $self->out( JSON::to_json( $self->data, { pretty => !($self->ugly) }) );
}

sub output_asv {
    require Text::CSV;

    my ($self, $args) = @_;
    my $o = $self->data->[0] or return;
    my @keys = ($self->fields) ? (@{$self->{fields}}) : ( grep { !ref($o->{$_}) } keys %$o );

    my $csv = Text::CSV->new({ binary => 1, %$args });
    $csv->combine(@keys);

    $self->out($csv->string);
    for $o (@{ $self->{data} }) {
        my $o_ = flatten($o);
        $csv->combine(@{$o_}{@keys});
        $self->out( $csv->string );
    }
}

sub output_csv {
    my ($self) = @_;
    $self->output_asv({ sep_char => "," });
}

sub output_tsv {
    my ($self) = @_;
    $self->output_asv({ sep_char => "\t" });
}

sub transform {
    my ($self) = @_;

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

    if ($self->map) {
        my $code = $self->map;
        for my $o (@{ $self->data }) {
            local %_ = %$o;
            eval "$code";
            %$o = %_;
        }
    }
    elsif ($self->fields) {
        my @fields = @{ $self->fields };
        my $data = $self->data;

        my $pick_fields_of_hash = sub {
            my $data = shift;
            my $data_ = flatten($data);

            for my $k (keys %$data_) {
                delete $data_->{$k} unless any { $k =~ m!(\A|[:\.]) \Q$_\E ([:\.]|\z)!x } @fields;
            }
            return unflatten($data_);
        };

        if (ref($data) eq "ARRAY") {
            for my $o (@$data) {
                %$o = %{ $pick_fields_of_hash->($o) };
            }
        }
        elsif (ref($data) eq "HASH") {
            %$data = %{ $pick_fields_of_hash->($data) };
        }
    }

    if ($self->output_flatten) {
        my $data = $self->data;
        if (ref($data) eq "HASH") {
            $self->data( flatten( $data ) );
        }
        elsif (ref($data) eq "ARRAY") {
            for my $o (@$data) {
                %$o = %{ flatten($o) };
            }
        }
    }

    return $self;
}

1;

__END__

=head1 jt - json transformer

=head1 SYNOPSIS

    # prettyfied
    curl http://example.com/action.json | jt

    # uglified
    cat random.json | jt --ugly > random.min.json

    # take only selected fields
    cat cities.json | jt --field name,country,latlon

    ## --pick, --grep, -map assumes the input is an array.
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

=head2 DESCRIPTION

jt assumes the input is some data serialized as JSON, and perform transformation
based on its parameter. It can be used to deal with various RESTful web service
api, such as ElasticSearch.

=head2 OUTPUT OPTIONS

The default output format is JSON. If C<--csv> is provided then simple fields
are chosen and then converted to CSV. If C<--tsv> is provided then it becomes
tab-separated values.

=head2 SELECTING FIELDS

The C<--field> option can be used to select only the wanted fields in the output.

The field name notation is based on L<Hash::Flatten> or C<MongoDB>. C<"."> is used
to delimit sub-fields within a hash, and C<":"> is used to delimit array elements.
Here's a brief example table that maps such flatten notation with perl expression:

    | flatten notation | perl expression        |
    |                  |                        |
    | foo.bar          | $_->{foo}{bar}         |
    | foo:0            | $_->{foo}[0]           |
    | foo.bar:3.baz    | $_->{foo}{bar}[3]{baz} |
    | foo.0.bar.4      | $_->{foo}{0}{bar}{4}   |

The C<--fields> option transform the input such that the output contain only
values of those fields. It may contain multilpe values seperated by comma,
such as:

    --fields title,address,phone

Each specified field name is matched to the flatten notation of full field
names. So C<"title"> would match any C<"title"> field an any depth in the input.

Then the input is an array of hash, then it applies on the hashes inside, so
the selection can be simplified.

