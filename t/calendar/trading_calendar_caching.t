use strict;
use warnings;

use Test::MockTime qw(:all);
use Test::More;
use Test::FailWarnings;
use Quant::Framework::TradingCalendar;
use Quant::Framework::InterestRate;
use Quant::Framework::Utils::Test;
use Data::Chronicle::Mock;

my ($chronicle_r, $chronicle_w) = Data::Chronicle::Mock::get_mocked_chronicle();
Quant::Framework::Utils::Test::create_doc(
    'currency',
    {
        symbol           => 'GBP',
        chronicle_reader => $chronicle_r,
        chronicle_writer => $chronicle_w,
    });

# check that cache is flushed after exchanges.yml is touched
my $LSE = Quant::Framework::TradingCalendar->new('LSE', $chronicle_r);
isa_ok $LSE, "Quant::Framework::TradingCalendar";
my $FOREX = Quant::Framework::TradingCalendar->new('FOREX', $chronicle_r);
isnt($FOREX, $LSE, "different objects for FOREX and LSE");
my $LSE2 = Quant::Framework::TradingCalendar->new('LSE', $chronicle_r);
is $LSE2, $LSE, "new returned the same M::E object";
my $METAL = Quant::Framework::TradingCalendar->new('METAL', $chronicle_r);
isnt($METAL, $LSE, "different objects for METAL and LSE");

set_relative_time(400);
note "Force Cache timeout";
my $LSE4 = Quant::Framework::TradingCalendar->new('LSE', $chronicle_r);
isnt($LSE4, $LSE, "new returned new M::E object");

done_testing;
