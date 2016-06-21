package Quant::Framework::Holiday;

use strict;
use warnings;

use Date::Utility;
use Quant::Framework::Document;
use Moo;
use List::Util qw(first);
use List::MoreUtils qw(uniq);

has document => (
    is => 'ro',
    required => 1,
);

my $_NAMESPACE = 'holidays';
# there are no per-symbol specialization of holiday, instead
# we store affected symbols for each holiday event
my $_SYMBOL = 'holidays';

sub create {
    my ($storage_accessor, $for_date) = @_;
    my $document = Quant::Framework::Document->new(
        storage_accessor => $storage_accessor,
        recorded_date    => $for_date,
        symbol           => $_SYMBOL,
        data             => { calendar => {} },
        namespace        => $_NAMESPACE,
    );

    return __PACKAGE__->new(
      document => $document,
    );
}

sub load {
    my ($storage_accessor, $for_date) = @_;

    my $document = Quant::Framework::Document::load($storage_accessor, $_NAMESPACE, $_SYMBOL, $for_date)
      or return;

    return __PACKAGE__->new(
      document => $document,
    );
}

sub save {
    my $self = shift;
    $self->document->save;
}

sub update {
    my ($self, $new_events, $new_date) = @_;
    my $recorded_date = $self->document->recorded_date->truncate_to_day->epoch;
    my $start_epoch = $new_date->truncate_to_day->epoch;

    # filter all events, that will happen later then $new_date
    my $persisted_events = $self->document->data->{calendar};
    my @actual_dates = grep { $_ >= $start_epoch} keys %$persisted_events;
    my %actual_events = @$persisted_events{@actual_dates};

    # append / update persisited events with new
    while (my ($new_holiday_date, $new_holiday) = each %$new_events) {
        my $epoch = Date::Utility->new($new_holiday_date)->truncate_to_day->epoch;

        my $persisted_event = $actual_events{$epoch};
        # persist new event, if it was completely absent
        if (!$persisted_event) {
            $actual_events{$epoch} = $new_holiday;

        # otherwise merge descriptions and affected symbols
        } else {
            while (my ($description, $new_symbols) = each %$new_holiday) {
                my @merged_symbols = uniq(@${ $persisted_event->{$description} }, @$new_symbols);
                $persisted_event->{$description} = \@merged_symbols;
            }
        }
    }

    my $new_document = Quant::Framework::Document->new(
        data             => { calendar => \%actual_events },
        storage_accessor => $self->document->storage_accessor,
        recorded_date    => $new_date,
        symbol           => $_SYMBOL,
        namespace        => $_NAMESPACE,
    );

    return __PACKAGE__->new(document => $new_document);
}

sub holidays_for {
    my ($storage_accessor, $symbol, $for_date) = @_;
    my $holiday = load($storage_accessor, $for_date);

    my $data = $holiday ? $holiday->document->data->{calendar} : {};

    my %holidays;
    while (my ($epoch, $holiday) = each %$data ) {
        while ( my ($description, $symbols) = each %$holiday ) {
            $holidays{$epoch} = $description if (first { $symbol eq $_ } @$symbols);
        }
    }
    return \%holidays;
}

1;
