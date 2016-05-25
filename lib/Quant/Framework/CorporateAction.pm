package Quant::Framework::CorporateAction;

use strict;
use warnings;

use Date::Utility;
use Quant::Framework::Document;
use Moo;

=head1 NAME

Quant::Framework::CorporateAction

=head1 DESCRIPTION

Represents the corporate actions data of an underlying from database. Create
new unpersistent CorporateAction can be done via:

 my $ca = Quant::Framework::CorporateAction::create($storage_accessor, 'QWER', Date::Utility->new);

Obviously, it will have empty actions hash

 $ca->actions; # empty hashref by default

Corporate actions can be persisted (stored in Chronicle) via C<save> method

 $ca->save;

Load persisted actions can be done via:

 my $ca = Quant::Framework::CorporateAction::load($storage_accessor, 'QWER', Date::Utility->new);

It will return C<undef> if there are no presisted actions in Chronicle. The date can be
ommitted, than, it will try to load the most recent (last) corporate actions, i.e.

 my $ca = Quant::Framework::CorporateAction::load($storage_accessor, 'QWER');


To update actions, the C<update> method should be invoked, with appropriate structure, i.e.

 my $ca = $ca->update({
   "62799500" => {
      "monitor_date" => "2014-02-07T06:00:07Z",
      "type" => "ACQUIS",
      "monitor" => 1,
      "description" =>  "Acquisition",
      "effective_date" =>  "15-Jul-14",
      "flag" => "N",
 }, Date::Utility->new);

The C<update> in scalar context will return B<new unpersisted> Corporate object. You have
to presist it via C<save> method.

In the list context it will return new unpersisted Corporate object, and two hasref for
new and cancelled action.


=cut

has document => (
    is => 'ro',
    required => 1,
);

my $_NAMESPACE = 'corporate_actions';

sub create {
    my ($storage_accessor, $symbol, $for_date) = @_;
    my $document = Quant::Framework::Document->new(
        storage_accessor => $storage_accessor,
        recorded_date    => $for_date,
        symbol           => $symbol,
        data             => { actions => {} },
        namespace        => $_NAMESPACE,
    );

    return __PACKAGE__->new(
      document => $document,
    );
}

sub load {
    my ($storage_accessor, $symbol, $for_date) = @_;

    my $document = Quant::Framework::Document::load($storage_accessor, $_NAMESPACE, $symbol, $for_date)
      or return;

    return __PACKAGE__->new(
      document => $document,
    );
}

sub save {
    my $self = shift;
    $self->document->save;
}

# creates new unpersisted (non-saved) CorporateAction object. You should invoke
# save method to persist it in Chronicle
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

    my %merged_actions = (%{ $data->{actions} }, %new);

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
        recorded_date    => $new_date,
        symbol           => $self->document->symbol,
        namespace        => $_NAMESPACE,
    );
    my $new_ca = __PACKAGE__->new(document => $new_document);

    return wantarray ? ($new_ca, \%new, \%cancelled) : $new_ca;
}

sub actions {
    return shift->document->data->{actions};
}

1;
