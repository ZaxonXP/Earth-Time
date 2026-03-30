#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(strftime);

# --- CONSTANTS & COSMIC DRIFT ---
use constant SECONDS_IN_DAY => 86400;
use constant LEAP_DAY_SECONDS => 86400;

# Tidal friction causes Earth to slow down. 
# Average slowing is 1.7ms per 100 years.
# We calculate the drift from a fixed epoch (e.g., year 2000).
sub get_tidal_slowing_offset {
    my ($year) = @_;
    my $centuries_since_2000 = ($year - 2000) / 100;
    # Total cumulative offset in seconds due to Earth's rotation slowing
    return ($centuries_since_2000 * 0.0017); 
}

sub is_gregorian_leap {
    my ($year) = @_;
    return ($year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0));
}

sub get_human_time {
    my ($timezone_offset) = @_;

    my $now = time();
    my @t = gmtime($now);
    my $yday = $t[7];
    my $year = $t[5] + 1900;

    # 1. TIDAL SLOWING ADJUSTMENT (The Atomic Factor)
    # This adjusts our "day" to match the actual, slowing rotation of Earth.
    my $tidal_offset = get_tidal_slowing_offset($year);

    # 2. GREGORIAN & ORBITAL DRIFT
    my $daily_leap_smear = is_gregorian_leap($year) ? (LEAP_DAY_SECONDS / 365) : 0;
    my $orbital_drift_per_day = 20926 / 365.2422;

    # 3. SEASONAL SINE-WAVE (Zenith Control)
    my $spring_eq = 80; 
    my $autumn_eq = 264;
    my $seasonal_corr = 0;
    if ($yday >= $spring_eq && $yday < $autumn_eq) {
        my $progress = ($yday - $spring_eq) / ($autumn_eq - $spring_eq);
        $seasonal_corr = sin(($progress * 2 - 1) * 1.5708) * 1800;
    } else {
        my $days_cycle = 365 - ($autumn_eq - $spring_eq);
        my $pos = ($yday < $spring_eq) ? ($yday + (365 - $autumn_eq)) : ($yday - $autumn_eq);
        $seasonal_corr = sin(($pos / $days_cycle * 2 - 1) * 1.5708) * -1800;
    }

    # 4. FINAL INTEGRATION
    my $standard_time = $now + ($timezone_offset * 3600);
    # Adding tidal_offset ensures we stay synced with the literal rotation speed
    my $total_corr = $seasonal_corr + ($yday * ($daily_leap_smear + $orbital_drift_per_day)) + $tidal_offset;
    my $human_time = $standard_time + $total_corr;

    # 5. THE BREATHING SECOND (Including tidal lag)
    my $daily_change = ($daily_leap_smear + $orbital_drift_per_day + ($tidal_offset / 365));
    my $sec_len = 1 + ($daily_change / SECONDS_IN_DAY);

    return ($human_time, $total_corr, $sec_len, $standard_time, $year, $tidal_offset);
}

# --- OUTPUT ---
my $tz = shift || 1; 
my ($h_time, $total_c, $s_len, $s_time, $yr, $t_off) = get_human_time($tz);

print "--- EARTH TIME: ATOMIC EDITION ---\n";
print "Current Year:        $yr\n";
print "Earth Rotation Lag:  +" . sprintf("%.6f", $t_off) . " s (Tidal Friction)\n";
print "Current Second Len:  " . sprintf("%.10f s", $s_len) . "\n";
print "Total Sync Offset:   " . sprintf("%.2f min", $total_c/60) . "\n";
print "------------------------------------------\n";
print "EARTH TIME:          " . strftime("%H:%M:%S", gmtime($h_time)) . "\n";
print "------------------------------------------\n";
print "Status: Atomic drift incorporated. Clock is breathing with Earth.\n";
