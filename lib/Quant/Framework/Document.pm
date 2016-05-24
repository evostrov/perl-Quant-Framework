package Quant::Framework::Document;

use strict;
use warnings;
use Date::Utility;

use Moo;

=head1 NAME

Quant::Framework::Document -

=head1 DESCRIPTION

Internal representation of persistend data. Do not use the class directly outside
of Quant::Framework.

The class is responsible for loading and stoing data via Data::Chronicle. The
data itself is a hash, which content is provided by users of the class (i.e. by
CorporateActions).

 # create new (trancient / not-yet-persisted) Document

 my $document = Quant::Framework::Document->new(
  storage_accessor => $storage_accessor,
  symbol           => 'frxUSDJPY',
  data             => {},
  for_date         => Date::Utility->new,
 );

 # persist document
 $document->save('currency');

 # load document
 my $document2 = Quant::Framework::Document::load(
  $storage_accessor,
  'currency',
  'frxUSDJPY',
  Date::Utility->new, # optional
 )

=cut


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
