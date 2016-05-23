#!/usr/bin/perl

use strict;
use warnings;

use Test::More; # tests => 2;
#use Test::NoWarnings;
use Date::Utility;

use Quant::Framework::Document;
use Quant::Framework::StorageAccessor;
use Quant::Framework::CorporateAction;
use Quant::Framework::Utils::Test;
use Data::Chronicle::Writer;
use Data::Chronicle::Reader;
use Data::Chronicle::Mock;

my ($chronicle_r, $chronicle_w) = Data::Chronicle::Mock::get_mocked_chronicle();

my $storage_accessor = Quant::Framework::StorageAccessor->new(
    chronicle_reader => $chronicle_r,
    chronicle_writer => $chronicle_w,
);

is Quant::Framework::CorporateAction::load($storage_accessor, 'FPGZ'),
    undef, 'document is not present';

my $now = time;

my $old_date = Date::Utility->new->minus_time_interval("15m");

subtest "load/save" => sub {
  my $ca = Quant::Framework::CorporateAction->new(
      document => Quant::Framework::Document->new(
          storage_accessor => $storage_accessor,
          for_date         => $old_date,
          symbol           => 'QWER',
          data             => {},
      )
  );
  ok $ca, "empty corporate actions object has been created";

  my $ca2 = $ca->update({
      "62799500" => {
          "monitor_date" => "2014-02-07T06:00:07Z",
          "type" => "ACQUIS",
          "monitor" => 1,
          "description" =>  "Acquisition",
          "effective_date" =>  "15-Jul-14",
          "flag" => "N"
      },
  }, $old_date);

  ok $ca2, "updated corporate actions object";
  $ca2->save;

  my $ca3 = Quant::Framework::CorporateAction::load($storage_accessor, 'QWER');
  ok $ca3;
  is $ca3->actions->{62799500}->{type}, "ACQUIS";
  is $ca3->actions->{62799500}->{effective_date}, "15-Jul-14";

  $ca3 = $ca2->update({
    "32799500" => {
        "monitor_date" => "2015-02-07T06:00:07Z",
        "type" => "DIV",
        "monitor" => 1,
        "description" =>  "Divided Stocks",
        "effective_date" =>  "15-Jul-15",
        "flag" => "N"
    },
  }, $old_date->plus_time_interval("5m"));
  $ca3->save;

  my $ca4 = Quant::Framework::CorporateAction::load($storage_accessor, 'QWER');
  is $ca4->actions->{62799500}->{type}, "ACQUIS";
  is $ca4->actions->{32799500}->{type}, "DIV";

  my $ca5 = Quant::Framework::CorporateAction::load($storage_accessor, 'QWER', $old_date);
  ok $ca5, "load via specifying exact date";
  is scalar(keys %{$ca5->actions}), 1, "old document contains 1 action";
};

done_testing;
