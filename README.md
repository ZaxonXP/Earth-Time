# 🌍 Earth Time (ET)

*A proposal to end clock jumps and tie civil time to the Sun – using the computing power we already carry in our pockets.*

---

## 💡 The Problem

Our civil timekeeping is a relic of the industrial age. We force billions of people to:

- **Jump 1 hour twice a year** (daylight saving time), with documented effects on sleep, traffic accidents and health.
- **Live by a clock that ignores the Sun**: solar noon wanders by up to ±16 minutes during the year (the equation of time), and by an hour or more when DST is applied.
- **Patch the clock with leap seconds**, because the Earth's rotation is slowly drifting away from atomic time.

---

## 🚀 The Solution: Earth Time

Instead of forcing humans to adapt to a rigid mechanical clock, Earth Time lets the clock follow the planet. It is a **presentation layer for civil time**, computed from UTC, in which the length of a second is a calculated variable.

### Key features of the reference script

- **Zero-jump transition:** no 1-hour jump. The seasonal ("DST") correction changes continuously, by at most about **30 seconds per day** around the equinoxes. By default it ranges from 0 (winter solstice) to +1 hour (summer solstice).
- **Solar-noon sync:** every day of the year, the Sun culminates at **12:00:00 + seasonal correction** on the meridian of your time zone (15° × UTC offset). In winter the correction is zero, so noon is exactly 12:00. The equation of time is removed completely.
- **The breathing second:** because the clock follows the real (apparent) Sun and a smooth seasonal curve, every Earth Time day has exactly 86,400 ET seconds, while the ET second varies between roughly **0.99944 s and 1.00040 s** of SI time over the year (−560 ppm … +400 ppm).
- **No dependence on the calendar:** the astronomy is computed from continuous time (Julian date), not from the day of the year, so leap years do not affect the clock or the equation of time.

> **What Earth Time does *not* do:** it does not remove February 29. The tropical year contains 365.2422 solar days, so the calendar *date* still needs leap days if seasons are to stay put on the calendar. Earth Time fixes the **time of day** (no DST jumps, no leap seconds in the display layer); the Gregorian leap rule stays for the **date**. A variable second cannot change the number of days in a year – only their length.

---

## 🛠️ Reference Implementation (Perl)

`earth_time.pl` is a proof of concept. It needs only Perl with standard core modules.

### How to run

```bash
perl earth_time.pl                       # default zone UTC+1
perl earth_time.pl --tz UTC-5            # US Eastern, standard meridian
perl earth_time.pl --tz UTC+5:30 --amp 1800
perl earth_time.pl --tz +1 --lat 52.23   # also prints sunrise/sunset
```

| Option | Meaning | Default |
| --- | --- | --- |
| `--tz` | time zone offset: `+1`, `UTC+1`, `-5`, `UTC+5:30` | `UTC+1` |
| `--amp` | maximum seasonal correction in seconds (`0` = off) | `3600` |
| `--lat` | optional latitude (N positive) – enables sunrise/sunset and selects the hemisphere for the seasonal curve | not set (northern hemisphere) |
| `--time` | Unix time to convert (for testing) | now |
| `--help` | show help |  |

### What the code does

1. **Computes the Sun's position** (equation of time and declination) with the NOAA/Meeus algorithm from the Julian date.
2. **Applies the seasonal curve:** `correction = amp · (δ / 23.44° + 1) / 2`, where δ is the solar declination. It is 0 at the winter solstice, `amp` at the summer solstice, and smooth in between. In the southern hemisphere (`--lat` negative) the curve is mirrored.
3. **Builds the Earth Time clock:** `ET = UTC + zone offset + equation of time + seasonal correction`.
4. **Calculates the second length:** `(86400 + LOD excess − d(EoT)/day − d(seasonal)/day) / 86400`, so a day is always 86,400 ET seconds.
5. **Prints** the ET clock, equation of time, seasonal correction, second length, solar noon and – if latitude is given – sunrise, sunset, day length and noon altitude.

---

## 📜 The Manifesto

*"Time was once a natural phenomenon. We turned it into a prison of gears and bits. It is time to use those same bits to set our biological clocks free."*

---

## Objections and Responses

| Objection | Response |
| --- | --- |
| "This will cause chaos in timetables!" | Trains and planes already operate on fixed UTC. Earth Time is a presentation layer for people; booking systems would recalculate it in the background, just as they do with time zones today. |
| "Mechanical watches will stop working." | ET is a system for the digital age: your main clock is your phone, watch or computer, and they can easily handle a variable second. |
| "What about February 29th?" | It stays. Earth Time is about the time of day, not the calendar; the Gregorian leap rule keeps the date aligned with the seasons. Birthdays are unaffected. |
| "What about places far from the zone's central meridian?" | Solar noon there differs by 4 minutes per degree of longitude, exactly as with today's zones. The reference script reports noon on the zone meridian. |
| "This is too mathematically complicated." | For humans – yes. For a phone processor it is microseconds of work. Technology should handle complex calculations so our lives can be simpler. |
| "People need a fixed second for science." | The SI second stays in labs, physics and networks. ET is civil time: just as a nautical mile differs from a kilometre, a civil second can breathe slightly. |
| "Is it accurate?" | The Sun's position is computed to within a few seconds. The base is UTC, which stays within 0.9 s of the Earth's rotation (UT1) thanks to leap seconds; a full implementation would use UT1 directly. |

---

# 📑 Technical Specification: Earth Time (ET) System

**Version:** 1.1 (matches `earth_time.pl`)\
**Code name:** Breathing Clock\
**Target platforms:** POSIX systems (Debian/Devuan), embedded systems, smartphones.

## 1. Operational definition

Earth Time is a model of civil time in which the length of a second is a computed variable. It keeps the clock synchronised with the daily and annual cycles of the Sun without abrupt corrections. Each ET day contains exactly 86,400 ET seconds, and the Sun culminates every day at a fixed ET time of day on the zone meridian.

## 2. Modules

### A. Solar module (equation of time)

- **Input:** Unix time (UTC ≈ UT1).
- **Algorithm:** NOAA/Meeus series for the equation of time and solar declination, from the Julian date; no dependency on day-of-year or leap years.
- **Effect:** apparent solar time replaces mean time; solar noon coincides with 12:00 + seasonal correction.
- **Range:** −14.2 min (mid-February) to +16.5 min (early November). Maximum rate of change about 30 s per day (December).

### B. Seasonal module (smooth "DST")

- **Formula:** `correction = amp · (δ / 23.44° + 1) / 2`, δ = solar declination (sign inverted for the southern hemisphere).
- **Amplitude (default):** 3600 s – from 0 in winter to +1 h in summer; adjustable with `--amp`.
- **Phase:** peak exactly at the summer solstice, zero at the winter solstice (no seasonal lag).
- **Gradient:** about 30 s per day around the equinoxes; no discontinuities.

### C. Rotation module (informational)

- **ΔT = TT − UT1:** estimated with the Espenak–Meeus polynomials (about 75 s for 2026 by this model; observed value is nearer 69 s).
- **Use:** the growth rate of ΔT (about 0.6 s/yr in the model) gives the excess length of day (about 1.7 ms/day) in the second-length formula. Its effect is several orders of magnitude smaller than the other two modules.
- **Leap seconds:** the ET display layer has no use for them, because it follows the Sun directly. The reference script takes UTC as input, so it still depends on leap seconds indirectly.

### D. Calendar

- Unchanged: Gregorian rules (4/100/400) remain in force for the date. Earth Time does not alter the number of days in a year.

## 3. "Breathing second" parameters

Values for 2026 with the default amplitude (1 h), relative to the SI second:

| State | ET second | Deviation |
| --- | --- | --- |
| Shortest (late March – early April) | \~0.99944 s | −560 ppm |
| Longest (December) | \~1.00040 s | +400 ppm |
| Winter solstice (EoT only) | \~1.00035 s | +350 ppm |
| ET day | 86,400 ET s | ≈ 86,350 – 86,430 SI s |

The second is short in spring because the seasonal correction and the Sun's advance both run fast, and long in late autumn and winter when the solar day itself is longest.

## 4. Proposed implementation

The system would be a daemon (`etd`) that:

- takes UTC from NTP (or UT1 where available),
- applies the ET computation for the user's zone,
- exposes the result as a presentation layer to applications. System time (`CLOCK_REALTIME`) and logs stay in UTC.

## 5. Known limitations

- The calendar still needs leap days; Earth Time only fixes the clock.
- Zones are represented by their central meridian. Places away from it have solar noon offset by 4 min per degree.
- The seasonal amplitude and phase are design parameters, not natural constants.
- Without `--lat`, the northern hemisphere is assumed and sunrise/sunset are not printed.
- ΔT is modelled and approximate.

## 6. Benefits

- **For humans:** no clock jumps, fewer "social jet lag" effects, noon tied to the Sun.
- **For IT:** no DST ambiguity (a repeated or missing hour), no leap-second anomalies in the presentation layer, logs stay in UTC.
- **For safety:** more daylight in the evening in summer, no sudden shift of the morning commute.

**System motto:**\
*"Technology should not measure time against humanity, but in harmony with its nature."*

## 7. Example implementation

The attached script `earth_time.pl` computes Earth Time with all the parameters above. The main option is the time zone (`--tz`); everything else is optional.
