package Quant::Framework::CorporateAction;

use Date::Utility;
use Quant::Framework::Document;
use Moo;

has document => (
    is => 'ro',
    required => 1,
);

sub load {
    my ($storage_accessor, $symbol, $for_date) = @_;

    my $document = Quant::Framework::Document::load($storage_accessor, 'corporate_actions', $symbol, $for_date)
      or return;

    return __PACKAGE__->new(
      document => $document,
    );
}

sub save {
    my $self = shift;
    $self->document->save('corporate_actions');
}

sub update {
    my ($self, $actions, $new_date) = @_;

    # clone original data
    my $original = $self->document->data;
    my $data = {%$original};

    my %new;
    foreach my $action_id (keys %$actions) {
        # flag 'N' = New & 'U' = Update
        my $action = $actions->{$action_id};
        my $is_new = ($action->{flag} eq 'N' and not $original->{actions}->{$action_id})
          || $action->{flag} eq 'U';

        $new{$action_id} = $action if ($is_new);
    }

    my %merged_actions = (%{ $data->{actions} // {} }, %new);

    my %cancelled;
    foreach my $action_id (keys %$actions) {
        my $action = $actions->{$action_id};
        # flag 'D' = Delete
        if ($action->{flag} eq 'D' and $original->{actions}->{$action_id}) {
            $cancelled{$action_id} = $action;
            delete $merged_actions{$action_id};
        }
    }

    $data->{actions} = \%merged_actions;

    my $new_document = Quant::Framework::Document->new(
        data             => $data,
        storage_accessor => $self->document->storage_accessor,
        for_date         => $new_date,
        symbol           => $self->document->symbol,
    );
    my $new_ca = __PACKAGE__->new(document => $new_document);

    return wantarray ? ($new_ca, \%new, \%cancelled) : $new_ca;
}

sub actions {
    return shift->document->data->{actions};
}

1;
