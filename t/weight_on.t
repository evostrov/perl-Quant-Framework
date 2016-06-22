#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;
use Test::NoWarnings;

use Quant::Framework::TradingCalendar;
use Date::Utility;

use Quant::Framework::Utils::Test;

my ($chronicle_r, $chronicle_w) = Data::Chronicle::Mock::get_mocked_chronicle();

my $date = Date::Utility->new('2013-12-01');
note("Exchange tests for_date " . $date->date);
Quant::Framework::Utils::Test::create_doc(
    'holiday',
    {
        recorded_date => $date,
        calendar      => {
            "25-Dec-2013" => {
                "Christmas Day" => [qw(FOREX)],
            },
        },
        chronicle_reader => $chronicle_r,
        chronicle_writer => $chronicle_w,
    });

subtest 'weight on' => sub {
    my $chritmas = Date::Utility->new('2013-12-25');
    my $forex = Quant::Framework::TradingCalendar->new({
            symbol => 'FOREX', 
            chronicle_reader => $chronicle_r, 
            locale => 'en', 
            for_date => $date});
    ok $forex->has_holiday_on($chritmas), 'has holiday on ' . $chritmas->date;
    is $forex->simple_weight_on($date), 0, 'weight is zero on a holiday';
    my $weekend = Date::Utility->new('2013-12-8');
    note($weekend->date . ' is a weekend');
    is $forex->simple_weight_on($weekend), 0, 'weight is zero on weekend';
    my $pseudo_holiday_date = Date::Utility->new('2013-12-24');
    note($pseudo_holiday_date->date . ' is a pseudo holiday');
    is $forex->simple_weight_on($pseudo_holiday_date), 0.5, 'zero for pseudo holiday';
    my $trading_date = Date::Utility->new('2013-12-2');
    is $forex->simple_weight_on($trading_date), 1, 'weight is 1 on a trading day';
};
