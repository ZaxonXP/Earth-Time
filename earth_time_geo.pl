#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(strftime);
use Math::Trig;

# --- CONSTANTS ---
use constant PI => 3.14159265358979;
use constant RAD => PI / 180;
use constant TIDAL_COEFF => 31; # Delta T constant

# --- INPUT PARAMETERS ---
# Usage: perl script.pl [lat] [lon] [base_tz]
my $lat      = shift || 52.23; # Latitude (North) - Warsaw default
my $lon      = shift || 21.01; # Longitude (East)
my $tz_base  = shift || 1;     # Base offset (UTC+1)

my $now = time();
my @local_t = localtime($now);
my $is_dst = $local_t[8]; # Detect DST from system
my $yday = $local_t[7];
my $year = $local_t[5] + 1900;

# Current active timezone offset (e.g., 2 if UTC+1 + DST)
my $active_tz = $tz_base + ($is_dst ? 1 : 0);

# 1. ASTRONOMICAL ADJUSTMENTS (Delta T & EoT)
# Delta T: Correction for Earth's rotation slowing
my $t_cen = ($year - 1820) / 100;
my $delta_t = TIDAL_COEFF * ($t_cen**2);

# Equation of Time (EoT): Correction for orbital eccentricity
my $b = 2 * PI * ($yday - 81) / 365;
my $eot_min = 9.87 * sin(2 * $b) - 7.53 * cos($b) - 1.5 * sin($b);
my $eot_sec = $eot_min * 60;

# 2. SOLAR GEOMETRY
my $d = $yday + 1;
my $declination = -23.44 * cos(RAD * (360/365.24 * ($d + 10)));

my $lat_rad = $lat * RAD;
my $decl_rad = $declination * RAD;
my $cos_h = -tan($lat_rad) * tan($decl_rad);

# Handle Polar Day/Night
$cos_h = 1 if $cos_h > 1;
$cos_h = -1 if $cos_h < -1;

my $hour_angle = acos($cos_h) / RAD;
my $half_day_hours = $hour_angle / 15;

# 3. CALCULATE REAL SOLAR NOON IN LOCAL TIME
# Solar noon (UTC) = 12:00 - (lon/15) - (EoT/60)
my $solar_noon_utc = 12 - ($lon / 15) - ($eot_min / 60);
my $solar_noon_local = $solar_noon_utc + $active_tz;

# 4. EARTH TIME (ET) DISPLAY LOGIC
# In ET, we fix noon at 12:00. These are relative times.
my $sunrise_et_dec = 12 - $half_day_hours;
my $sunset_et_dec  = 12 + $half_day_hours;

sub dec_to_time {
    my $dec = shift;
    while ($dec >= 24) { $dec -= 24; }
    while ($dec < 0) { $dec += 24; }
    my $h = int($dec);
    my $m = int(($dec - $h) * 60);
    my $s = int(((($dec - $h) * 60) - $m) * 60);
    return sprintf("%02d:%02d:%02d", $h, $m, $s);
}

# --- OUTPUT ---
print "--- EARTH TIME GEOLOCATION ENGINE (RECALIBRATED) ---\n";
print "Location:      Lat $lat, Lon $lon\n";
print "Current Date:  " . strftime("%Y-%m-%d", localtime($now)) . " (Day $d)\n";
print "DST Active:    " . ($is_dst ? "Yes (+1h)" : "No") . "\n";
print "----------------------------------------------------\n";
print "Delta T (Lag):         " . sprintf("%.2f s", $delta_t) . "\n";
print "Equation of Time:      " . sprintf("%.2f min", $eot_min) . "\n";
print "----------------------------------------------------\n";
print "SOLAR NOON (Local):    " . dec_to_time($solar_noon_local) . "\n";
print "SUNRISE (ET Scale):    " . dec_to_time($sunrise_et_dec) . "\n";
print "SUNSET  (ET Scale):    " . dec_to_time($sunset_et_dec) . "\n";
print "DAYLIGHT DURATION:     " . sprintf("%.2f hours", $half_day_hours * 2) . "\n";
print "----------------------------------------------------\n";
print "Note: Earth Time (ET) anchors 12:00:00 to the Solar Noon.\n";
