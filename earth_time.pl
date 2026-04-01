#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(strftime);

# --- ASTRONOMICAL CONSTANTS ---
use constant SECONDS_IN_DAY => 86400;
# Delta T (TT - UT1 difference) increases quadratically: approx 31s / century^2
use constant TIDAL_COEFF    => 31; 

sub get_astronomical_adjustments {
    my ($yday, $year) = @_;

    # 1. TIDAL SLOWING (Delta T)
    # Simplified model for the modern era: ΔT ≈ 31 * t^2
    # where t is centuries elapsed since 1820 (the zero point for rotation rate)
    my $t = ($year - 1820) / 100;
    my $delta_t = TIDAL_COEFF * ($t**2);

    # 2. EQUATION OF TIME (EoT)
    # Approximation of the difference between Apparent Solar Time and Mean Solar Time.
    # Factors in Earth's axial tilt and orbital eccentricity.
    # Result in minutes, converted to seconds.
    my $b = 2 * 3.14159 * ($yday - 81) / 365;
    my $eot = 9.87 * sin(2 * $b) - 7.53 * cos($b) - 1.5 * sin($b);
    my $eot_seconds = $eot * 60;

    # 3. TROPICAL YEAR DRIFT
    # Difference between Calendar Year (365.25) and Tropical Year (365.2422)
    # This drift is roughly 0.0078 days per year (~674 seconds)
    my $orbital_drift = ($year - 2000) * 673.92;

    return ($delta_t, $eot_seconds, $orbital_drift);
}

sub get_human_time {
    my ($timezone_offset) = @_;

    my $now = time();
    my @t = gmtime($now);
    my $yday = $t[7];
    my $year = $t[5] + 1900;

    my ($delta_t, $eot_sec, $drift) = get_astronomical_adjustments($yday, $year);

    # Standard System Time (Unix) + timezone offset
    my $standard_time = $now + ($timezone_offset * 3600);
    
    # Final synchronization with the "Solar Clock"
    # Delta T corrects for rotation slowing, EoT corrects for orbital mechanics
    my $total_corr = $eot_sec - $delta_t;
    my $human_time = $standard_time + $total_corr;

    # Calculate dynamic second length for the current era
    # Derived from the cumulative Delta T shift
    my $sec_len = 1 + ($delta_t / (SECONDS_IN_DAY * 365 * 100));

    return ($human_time, $total_corr, $sec_len, $year, $delta_t, $eot_sec);
}

# --- OUTPUT ---
my $tz = shift || 0; # Defaults to UTC
my ($h_time, $total_c, $s_len, $yr, $dt, $eot) = get_human_time($tz);

print "--- EARTH TIME: REALIGNMENT EDITION ---\n";
print "Current Year:        $yr\n";
print "Delta T (Accumulated): " . sprintf("%.2f s", $dt) . "\n";
print "Equation of Time:    " . sprintf("%.2f s", $eot) . "\n";
print "Current Second Len:  " . sprintf("%.10f s", $s_len) . "\n";
print "------------------------------------------\n";
print "SYSTEM TIME (UTC):   " . strftime("%H:%M:%S", gmtime(time())) . "\n";
print "EARTH TIME (Actual): " . strftime("%H:%M:%S", gmtime($h_time)) . "\n";
print "------------------------------------------\n";
