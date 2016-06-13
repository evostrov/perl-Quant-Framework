=head1 NAME

01_cutoff.t

=head1 DESCRIPTION

General unit tests for Quant::Framework::VolSurface::Cutoff.

=cut

use Test::Most;
use Test::MockTime qw( set_absolute_time restore_time );
use Test::FailWarnings;
use Test::MockModule;
use File::Spec;
use JSON qw(decode_json);

use Date::Utility;
use Quant::Framework::Utils::Test;
use Quant::Framework::VolSurface::Moneyness;

my ($chronicle_r, $chronicle_w) = Data::Chronicle::Mock::get_mocked_chronicle();
my $underlying_config = Quant::Framework::Utils::Test::create_underlying_config('frxUSDJPY');
my $builder = Quant::Framework::Utils::Builder->new({
    chronicle_reader => $chronicle_r,
    chronicle_writer => $chronicle_w,
    underlying_config => $underlying_config
  });
my $calendar = $builder->build_trading_calendar;

subtest 'Private method _cutoff_date_for_effective_day' => sub {
    plan tests => 5;

    my $cutoff     = Quant::Framework::VolSurface::Cutoff->new('New York 10:00');

    is(
        $cutoff->cutoff_date_for_effective_day(Date::Utility->new('2011-11-22 02:00:00'), $calendar)->datetime_yyyymmdd_hhmmss,
        '2011-11-22 15:00:00',
        'Next NY10am cutoff date after 2011-11-21 02:00:00.'
    );

    my $builder_hsi = Quant::Framework::Utils::Builder->new({
        chronicle_reader => $chronicle_r,
        chronicle_writer => $chronicle_w,
        underlying_config => Quant::Framework::Utils::Test::create_underlying_config('HSI'),
      });
    my $calendar_hsi = $builder_hsi->build_trading_calendar;

    is(
        $cutoff->cutoff_date_for_effective_day(Date::Utility->new('2011-11-22 03:00:00'), $calendar_hsi)
            ->datetime_yyyymmdd_hhmmss,
        '2011-11-22 15:00:00',
        'Given the HSI, next NY10am cutoff date after 2011-11-21 02:00:00.'
    );

    is(
        $cutoff->cutoff_date_for_effective_day(Date::Utility->new('2011-03-22 04:00:00'), $calendar)->datetime_yyyymmdd_hhmmss,
        '2011-03-22 14:00:00',
        'Next NY10am cutoff date after 2011-03-21 02:00:00 (in summer).'
    );

    $cutoff = Quant::Framework::VolSurface::Cutoff->new('UTC 21:00');
    is(
        $cutoff->cutoff_date_for_effective_day(Date::Utility->new('2012-03-02 02:00:00'), $calendar)->datetime_yyyymmdd_hhmmss,
        '2012-03-02 21:00:00',
        'Friday cutoff_date for an FX pair.'
    );

    $cutoff = Quant::Framework::VolSurface::Cutoff->new('UTC 23:59');
    is(
        $cutoff->cutoff_date_for_effective_day(Date::Utility->new('2012-04-23 00:00:00'), $calendar)->datetime_yyyymmdd_hhmmss,
        '2012-04-22 23:59:00',
        'Monday cutoff_date (falls on Sunday night GMT) for an FX pair.',
    );
};

subtest 'seconds_to_cutoff_time' => sub {
    plan tests => 7;

    my $cutoff     = Quant::Framework::VolSurface::Cutoff->new('New York 10:00');

    throws_ok {
        $cutoff->seconds_to_cutoff_time;
    }
    qr/No "from" date given/, 'Calling seconds_to_cutoff_time without "from" date.';
    throws_ok {
        $cutoff->seconds_to_cutoff_time({from => 1});
    }
    qr/No Calendar given/, 'Calling seconds_to_cutoff_time without underlying.';
    throws_ok {
        $cutoff->seconds_to_cutoff_time({
            from       => 1,
            calendar   => 1,
        });
    }
    qr/No maturity given/, 'Calling seconds_to_cutoff_time without maturity.';

    is(
        $cutoff->seconds_to_cutoff_time({
                from       => Date::Utility->new('2011-11-22 23:00:00'),
                maturity   => 1,
                calendar => $calendar,
            }
        ),
        40 * 3600 - 2,
        '2300GMT and 10am New York cutoff.'
    );

    is(
        $cutoff->seconds_to_cutoff_time({
                from       => Date::Utility->new('2011-11-22 04:00:00'),
                maturity   => 1,
                calendar => $calendar
            }
        ),
        35 * 3600 - 1,
        '0400GMT and 10am New York cutoff.'
    );

    is(
        $cutoff->seconds_to_cutoff_time({
                from       => Date::Utility->new('2011-11-22 00:00:00'),
                maturity   => 1,
                calendar => $calendar
            }
        ),
        39 * 3600 - 1,
        '0000GMT and 10am New York cutoff (2am NY).'
    );

    $cutoff = Quant::Framework::VolSurface::Cutoff->new('New York 10:00');
    is(
        $cutoff->seconds_to_cutoff_time({
                from       => Date::Utility->new('2011-06-14 23:00:00'),
                maturity   => 1,
                calendar => $calendar
            }
        ),
        39 * 3600 - 2,
        '2300GMT and 10am New York cutoff (summer, summer, summertime).'
    );
};

subtest code_gmt => sub {
    plan tests => 3;

    my $cutoff = Quant::Framework::VolSurface::Cutoff->new('UTC 15:00');
    is($cutoff->code_gmt, 'UTC 15:00', 'UTC equivalent of a UTC cutoff.');

    set_absolute_time(Date::Utility->new('2012-01-05 10:00:00')->epoch);
    $cutoff = Quant::Framework::VolSurface::Cutoff->new('New York 10:00');
    is($cutoff->code_gmt, 'UTC 15:00', 'UTC equivalent of NY1000 cutoff code in winter.');

    set_absolute_time(Date::Utility->new('2012-07-05 10:00:00')->epoch);
    $cutoff = Quant::Framework::VolSurface::Cutoff->new('New York 10:00');
    is($cutoff->code_gmt, 'UTC 14:00', 'UTC equivalent of NY1000 cutoff code in winter.');

    restore_time();
};

subtest cutoff_date_for_effective_day => sub {
    plan tests => 1;

    my $cutoff = Quant::Framework::VolSurface::Cutoff->new('UTC 23:59');

    my $cutoff_date = $cutoff->cutoff_date_for_effective_day(Date::Utility->new('2012-06-21'), $calendar);

    is($cutoff_date->date_yyyymmdd, '2012-06-20', 'UTC 23:59 cutoff date for effective day.');
};

done_testing;
