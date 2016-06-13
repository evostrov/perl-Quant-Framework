use Test::Most;
use Test::FailWarnings;
use Test::MockTime qw( set_absolute_time );
use Test::MockModule;
use File::Spec;
use JSON qw(decode_json);

use Date::Utility;
use Quant::Framework::Utils::Test;
use Quant::Framework::VolSurface::Utils;
use Quant::Framework::VolSurface::Delta;
use Quant::Framework::VolSurface::Moneyness;

my ($chronicle_r, $chronicle_w) = Data::Chronicle::Mock::get_mocked_chronicle();

my $date = Date::Utility->new('2016-05-25');
subtest "default_bloomberg_cutoff" => sub {
    plan tests => 3;
    my $forex = Quant::Framework::Utils::Test::create_underlying_config('frxUSDJPY');
    my $volsurface = Quant::Framework::VolSurface::Delta->new({
        underlying_config => $forex, 
        _new_surface => 1,
        chronicle_reader => $chronicle_r,
        chronicle_writer => $chronicle_w,
      });
    is($volsurface->cutoff->code, 'New York 10:00', 'Gets New York 10:00 for forex market');
    
    my $commodity = Quant::Framework::Utils::Test::create_underlying_config('frxXAUUSD');
    $volsurface = Quant::Framework::VolSurface::Delta->new({
        underlying_config => $commodity, 
        _new_surface => 1,
        chronicle_reader => $chronicle_r,
        chronicle_writer => $chronicle_w,
      });
    is($volsurface->cutoff->code, 'New York 10:00', 'Default cutoff for a commodity.');

    my $indices = Quant::Framework::Utils::Test::create_underlying_config('SPC');
    $volsurface = Quant::Framework::VolSurface::Moneyness->new({
        underlying_config => $indices, 
        _new_surface => 1,
        chronicle_reader => $chronicle_r,
        chronicle_writer => $chronicle_w,
      });
    isnt($volsurface->cutoff->code, 'New York 10:00', 'Anything other than New York 10:00 for indices');
};

subtest "NY1700_rollover_date_on" => sub {
    plan tests => 2;
    my $date_apr = Date::Utility->new('12-APR-12 16:00');
    my $util     = Quant::Framework::VolSurface::Utils->new();
    is($util->NY1700_rollover_date_on($date_apr)->datetime, '2012-04-12 21:00:00', 'Correct rollover time in April');
    my $date_nov = Date::Utility->new('12-NOV-12 16:00');
    is($util->NY1700_rollover_date_on($date_nov)->datetime, '2012-11-12 22:00:00', 'Correct rollover time in November');
};

subtest "effective_date_for" => sub {
    plan tests => 2;
    my $date_apr = Date::Utility->new('12-APR-12 16:00');
    my $util     = Quant::Framework::VolSurface::Utils->new();
    is($util->effective_date_for($date_apr)->date, '2012-04-12', 'Correct effective date in April');
    my $date_nov = Date::Utility->new('12-NOV-12 16:00');
    $util = Quant::Framework::VolSurface::Utils->new();
    is($util->effective_date_for($date_nov)->date, '2012-11-12', 'Correct effective date in November');
};

subtest default_bloomberg_cutoff => sub {
    plan tests => 4;

    my $util = Quant::Framework::VolSurface::Utils->new;

    foreach my $date_str (qw(2012-10-05 2012-10-06 2012-10-07 2012-10-08)) {
        set_absolute_time(Date::Utility->new($date_str . ' 10:00:00')->epoch);

        my $AS51 = Quant::Framework::Utils::Test::create_underlying_config('AS51');
        my $volsurface = Quant::Framework::VolSurface::Moneyness->new({
            underlying_config => $AS51, 
            _new_surface => 1,
            chronicle_reader => $chronicle_r,
            chronicle_writer => $chronicle_w,
          });

        is($volsurface->cutoff->code, 'UTC 06:00', 'Cutoff on Saturday before a DST spring forward.');
    }
};

done_testing;
