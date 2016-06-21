package Quant::Framework::Holiday;

use strict;
use warnings;

use Date::Utility;
use Moo;
use List::Util qw(first);
use List::MoreUtils qw(uniq);

with('Quant::Framework::Document');

sub namespace { 'holidays' }

sub default_section { 'calendar' }

# override default create function, to supply symbol, as we don't have
# symbol for Holiday (it is equal to 'holidays')
sub create {
    my ($package, $storage_accessor, $for_date) = @_;
    $package->create_default($storage_accessor, namespace, $for_date);
}

sub load {
    my ($package, $storage_accessor, $for_date) = @_;
    $package->load_default($storage_accessor, namespace, $for_date);
}

sub update {
    my ($self, $new_events, $new_date) = @_;
    my $recorded_date = $self->recorded_date->truncate_to_day->epoch;
    my $start_epoch   = $new_date->truncate_to_day->epoch;

    # filter all events, that will happen later then $new_date
    my $persisted_events = $self->data->{calendar};
    my @actual_dates     = grep { $_ >= $start_epoch } keys %$persisted_events;
    my %actual_events    = @$persisted_events{@actual_dates};

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
                my @merged_symbols = uniq(@${$persisted_event->{$description}}, @$new_symbols);
                $persisted_event->{$description} = \@merged_symbols;
            }
        }
    }

    my $new_obj = __PACKAGE__->new(
        data             => {calendar => \%actual_events},
        storage_accessor => $self->storage_accessor,
        recorded_date    => $new_date,
        symbol           => namespace,
    );

    return $new_obj;
}

sub holidays_for {
    my ($storage_accessor, $symbol, $for_date) = @_;
    my $holiday = __PACKAGE__->load($storage_accessor, $for_date);

    my $data = $holiday ? $holiday->data->{calendar} : {};

    my %holidays;
    while (my ($epoch, $holiday) = each %$data) {
        while (my ($description, $symbols) = each %$holiday) {
            $holidays{$epoch} = $description if (first { $symbol eq $_ } @$symbols);
        }
    }
    return \%holidays;
}

1;
