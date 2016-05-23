package Quant::Framework::Document;

use strict;
use warnings;
use Date::Utility;

use Moo;

has storage_accessor => (
    is => 'ro',
    required => 1,
);

has for_date => (
    is      => 'ro',
    isa     => sub {
      die("Quant::Framework::Document::for_date should be Date::Utility")
        unless ref($_[0]) eq 'Date::Utility';
    },
    required => 1,
);

has data => (
    is => 'ro',
    required => 1,
);

has symbol => (
    is       => 'ro',
    required => 1,
);

sub load {
    my ($storage_accessor, $namepace, $symbol, $for_date) = @_;

    my $data = $storage_accessor->chronicle_reader->get('corporate_actions', $symbol)
      or return;

    if ($for_date && $for_date->datetime_iso8601 lt $data->{date}) {
        $data = $storage_accessor->chronicle_reader->get_for('corporate_actions', $symbol, $for_date->epoch)
          or return;
    }

    return __PACKAGE__->new(
        storage_accessor => $storage_accessor,
        for_date         => $for_date // Date::Utility->new($data->{date}),
        symbol           => $symbol,
        data             => $data,
    );
}

sub save {
    my ($self, $namespace) = @_;
    $self->data->{date} = $self->for_date->datetime_iso8601;
    $self->storage_accessor->chronicle_writer->set($namespace, $self->symbol, $self->data, $self->for_date);
}

1;
