#!/usr/bin/perl
# EARTH TIME - a solar clock with a variable-length second and a smooth "DST"
#
# 12:00:00 Earth Time = the Sun culminating on the meridian of the time zone
# (15° * offset), every day of the year. No DST jumps, no dependence on leap years.
# In summer a smooth seasonal correction is added to the clock (default: up to +1 h).
#
# Usage:  perl earth_time.pl [options]
#   --tz ZONE      time zone, e.g. +1, UTC+1, UTC-5, UTC+5:30   (default UTC+1)
#   --amp SECONDS  maximum seasonal correction in seconds, 0 = off (default 3600)
#   --lat DEGREES  optional: latitude (north positive) - enables sunrise/sunset
#                  and the correct hemisphere for the smooth DST (default: north)
#   --time EPOCH   Unix time to convert (default: now)
#   --help         this help
use strict;
use warnings;
use utf8;
use POSIX qw(strftime floor fmod);
use Math::Trig qw(deg2rad rad2deg acos asin tan);
use Time::HiRes qw(time);
use Getopt::Long qw(GetOptions);

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

# ---------------------------------------------------------------- options
my ($tz_str, $lat, $amp, $now_opt, $help) = ('UTC+1', undef, 3600, undef, 0);
GetOptions(
    'tz=s'   => \$tz_str,
    'lat=f'  => \$lat,
    'amp=f'  => \$amp,
    'time=f' => \$now_opt,
    'help|h' => \$help,
) or die "Błędne opcje. Użyj --help.\n";

if ($help) {
    open(my $fh, '<:encoding(UTF-8)', $0) or exit;
    while (<$fh>) { next if $. == 1; last unless /^#/; s/^# ?//; print }
    exit;
}

# "UTC+1", "+1", "-5", "UTC+5:30", "5.5" -> hours (number)
sub parse_tz {
    my $orig = shift;
    my $s = $orig;
    $s =~ s/^\s*(?:UTC|GMT)\s*//i;
    $s =~ s/\s+$//;
    if ($s =~ /^([+-]?)(\d{1,2}):(\d{2})$/) {
        my $v = $2 + $3 / 60;
        return $1 eq '-' ? -$v : $v;
    }
    return $s + 0 if $s =~ /^[+-]?\d+(?:\.\d+)?$/;
    die "Nie rozumiem strefy '$orig'. Przykłady: UTC+1, -5, UTC+5:30\n";
}
my $tz  = parse_tz($tz_str);
die "Strefa poza zakresem (-12…+14)\n" if $tz < -12 || $tz > 14;
my $now = defined $now_opt ? $now_opt : time();

# ------------------------------------------------------------ astronomy
sub norm360 { my $x = fmod($_[0], 360); $x += 360 if $x < 0; return $x }

# Equation of time [s] and solar declination [deg] (NOAA/Meeus algorithm, continuous time)
sub solar_params {
    my $ut = shift;
    my $jd = $ut / 86400 + 2440587.5;
    my $T  = ($jd - 2451545.0) / 36525;

    my $L0  = norm360(280.46646 + $T * (36000.76983 + $T * 0.0003032));
    my $M   = norm360(357.52911 + $T * (35999.05029 - $T * 0.0001537));
    my $e   = 0.016708634 - $T * (0.000042037 + $T * 0.0000001267);
    my $om  = 125.04 - 1934.136 * $T;
    my $eps = 23.439291 - 0.0130042 * $T + 0.00256 * cos(deg2rad($om));

    my $y  = tan(deg2rad($eps) / 2) ** 2;
    my $l0 = deg2rad($L0);
    my $m  = deg2rad($M);

    my $E = $y * sin(2*$l0) - 2*$e*sin($m)
          + 4*$e*$y*sin($m)*cos(2*$l0)
          - 0.5*$y**2*sin(4*$l0) - 1.25*$e**2*sin(2*$m);
    my $eot = 240 * rad2deg($E);

    my $C = (1.914602 - $T*(0.004817 + 0.000014*$T)) * sin($m)
          + (0.019993 - 0.000101*$T) * sin(2*$m)
          + 0.000289 * sin(3*$m);
    my $lam  = $L0 + $C - 0.00569 - 0.00478 * sin(deg2rad($om));
    my $decl = rad2deg(asin(sin(deg2rad($eps)) * sin(deg2rad($lam))));

    return ($eot, $decl);
}

# Smooth seasonal correction [s]: 0 in winter, $amp in summer, no jumps
sub smooth_dst {
    my $ut   = shift;
    my $decl = (solar_params($ut))[1];
    my $s    = (defined $lat && $lat < 0) ? -$decl : $decl;
    return $amp * ($s / 23.44 + 1) / 2;
}

# Delta T = TT - UT1 [s] and its growth rate [s/year] (Espenak-Meeus)
sub delta_t {
    my $year = shift;
    if ($year >= 2005 && $year < 2050) {
        my $t = $year - 2000;
        return (62.92 + 0.32217*$t + 0.005589*$t**2, 0.32217 + 2*0.005589*$t);
    }
    my $u = ($year - 1820) / 100;
    return (-20 + 32*$u**2, 64*$u/100);
}

# ------------------------------------------------------------ calculations
my ($eot, $decl) = solar_params($now);
my $dst = smooth_dst($now);
my $year_frac = 2000 + ($now / 86400 + 2440587.5 - 2451545.0) / 365.25;
my ($dT, $dT_rate) = delta_t($year_frac);

# Variable second length: an Earth Time day is always 86400 Earth seconds
my $d_eot_day  = (solar_params($now + 43200))[0] - (solar_params($now - 43200))[0];
my $d_dst_day  = smooth_dst($now + 43200) - smooth_dst($now - 43200);
my $lod_excess = $dT_rate / 365.25;
my $sec_len    = (86400 + $lod_excess - $d_eot_day - $d_dst_day) / 86400;

# Zone clock (UTC ~ UT1, difference < 0.9 s)
my $zone_clock = $now + $tz * 3600 + $eot + $dst;
my $noon_zone  = 43200 + $dst;      # Sun's culmination on the zone meridian

sub hms {
    my $s = fmod(shift, 86400);
    $s += 86400 if $s < 0;
    $s = floor($s);
    return sprintf("%02d:%02d:%02d", int($s / 3600), int(($s % 3600) / 60), $s % 60);
}
sub tz_label {
    my $v = shift;
    my $sign = $v < 0 ? '-' : '+';
    $v = abs($v);
    my $h = int($v);
    my $m = int(($v - $h) * 60 + 0.5);
    return sprintf("UTC%s%d%s", $sign, $h, $m ? sprintf(":%02d", $m) : '');
}

# ------------------------------------------------------------------ output
print "=== EARTH TIME (czas ziemski) ===\n";
printf "Strefa:                %s (południk %.1f°)\n", tz_label($tz), 15 * $tz;
printf "Data (czas ziemski):   %s\n", strftime("%Y-%m-%d", gmtime(floor($zone_clock)));
print  "----------------------------------------------------\n";
printf "UTC:                   %s\n", hms($now);
printf "Zegar systemowy (DST): %s\n", strftime("%H:%M:%S", localtime($now));
printf "CZAS ZIEMSKI:          %s   (płynne DST: %+.1f min)\n", hms($zone_clock), $dst / 60;
print  "----------------------------------------------------\n";
printf "Równanie czasu:        %+.2f min (%+.1f s)\n", $eot / 60, $eot;
printf "Zmiana EoT / DST:      %+.2f / %+.2f s/dobę\n", $d_eot_day, $d_dst_day;
printf "Długość sekundy ziem.: %.10f s SI  (%+.1f ppm)\n", $sec_len, ($sec_len - 1) * 1e6;
printf "Doba słoneczna:        %.3f s SI\n", 86400 * $sec_len;
printf "ΔT (informacyjnie):    %.1f s, rośnie %.2f s/rok\n", $dT, $dT_rate;
print  "----------------------------------------------------\n";
printf "Południe słoneczne:    %s (na południku strefy)\n", hms($noon_zone);
printf "Deklinacja Słońca:     %+.2f°\n", $decl;

if (defined $lat) {
    my $cos_h = (cos(deg2rad(90.833)) - sin(deg2rad($lat)) * sin(deg2rad($decl)))
              / (cos(deg2rad($lat))   * cos(deg2rad($decl)));
    my $polar = $cos_h > 1 ? 'noc polarna' : $cos_h < -1 ? 'dzień polarny' : '';
    $cos_h = 1 if $cos_h > 1;
    $cos_h = -1 if $cos_h < -1;
    my $half = rad2deg(acos($cos_h)) / 15 * 3600;
    my $alt  = 90 - abs($lat - $decl);
    if ($polar) {
        print "Wschód / zachód:       $polar\n";
    } else {
        printf "Wschód Słońca:         %s\n", hms($noon_zone - $half);
        printf "Zachód Słońca:         %s\n", hms($noon_zone + $half);
    }
    printf "Długość dnia:          %.2f h\n", $half * 2 / 3600;
    printf "Wysokość w południe:   %.1f°%s\n", $alt, ($alt > 89.95 ? ' (Słońce w zenicie)' : '');
}
