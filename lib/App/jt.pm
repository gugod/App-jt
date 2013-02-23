package App::jt;

use Moo;
use MooX::Options;
use JSON;
use Hash::Flatten qw(flatten);

option 'delimiter' => ( is => "ro", default => sub { "\t" } );

option 'fields'    => (
    is => "ro",
    format => "s@"
);

sub run {
    my ($self) = @_;
    my $data = do { local $/; JSON::from_json(<STDIN>) };

    if (ref($data) eq "ARRAY") {
        $self->handle_array($data);
    }
    else {
        die "No idea how to transform that.\n";
    }
}

sub handle_array {
    my ($self, $data) = @_;
    my @keys = $self->fields ? @{ $self->fields } : sort keys %{ flatten($data->[0]) };

    for my $row (@$data) {
        if (ref($row) eq "HASH") {
            $self->emit( values => [ @{flatten($row)}{@keys} ]);
        }
    }
}

sub emit {
    my ($self, $type, $data) = @_;
    my $delimiter = $self->delimiter;
    if ($type eq "keys") {
        print STDOUT "#".join($delimiter => @$data)."\n";
    }
    if ($type eq "values") {
        print STDOUT join($delimiter => @$data) . "\n";
    }
}

1;
