package App::jt;
# ABSTRACT: JSON transformer

use 5.010;
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

option 'json_path' => (
    is => "ro",
    doc => "A JSONPath string for filtering document.",
    format => "s",
);

has data => (
    is => "rw",
    doc => "The data that keeps transforming."
);

sub run {
    my ($self) = @_;
    binmode STDIN => ":utf8";

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
    elsif ($self->json_path) {
        require JSON::Path;

        my $jpath = JSON::Path->new($self->json_path);
        my @values = $jpath->values($self->data);

        $self->data( \@values );
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

