import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/utils/opening_hours.dart';

/// The `opening_hours` reader answers "are you open now" for the common OSM
/// forms and returns `null` (→ the caller shows the raw tag) for anything it
/// cannot be sure about.
void main() {
  // A Monday.
  DateTime monday(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 26, hour, minute);
  // A Saturday.
  DateTime saturday(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 31, hour, minute);

  OpeningHoursStatus? eval(
    String? hours,
    DateTime at, {
    bool isPublicHoliday = false,
  }) => evaluateOpeningHours(hours, at, isPublicHoliday: isPublicHoliday);

  test('24/7 is always open with no next change', () {
    expect(
      eval('24/7', monday(3)),
      const OpeningHoursStatus(state: OpeningState.open),
    );
  });

  test('a plain range reports open, closing soon and closed', () {
    expect(
      eval('09:00-18:00', monday(12)),
      const OpeningHoursStatus(
        state: OpeningState.open,
        nextChangeMinutes: 18 * 60,
      ),
    );
    // 30 min before closing → "closing soon".
    expect(
      eval('09:00-18:00', monday(17, 30)),
      const OpeningHoursStatus(
        state: OpeningState.closingSoon,
        nextChangeMinutes: 18 * 60,
      ),
    );
    // 30 min before opening → "opening soon".
    expect(
      eval('09:00-18:00', monday(8, 30)),
      const OpeningHoursStatus(
        state: OpeningState.openingSoon,
        nextChangeMinutes: 9 * 60,
      ),
    );
    expect(
      eval('09:00-18:00', monday(20)),
      const OpeningHoursStatus(state: OpeningState.closed),
    );
  });

  test('the OSM example Mo-Fr 08:00-20:00; PH,Sa,Su 09:00-20:00', () {
    const String hours = 'Mo-Fr 08:00-20:00; PH,Sa,Su 09:00-20:00';
    // Weekday: the Mo-Fr rule.
    expect(
      eval(hours, monday(11)),
      const OpeningHoursStatus(
        state: OpeningState.open,
        nextChangeMinutes: 20 * 60,
      ),
    );
    // Saturday: only the PH,Sa,Su rule applies.
    expect(
      eval(hours, saturday(8, 30)),
      const OpeningHoursStatus(
        state: OpeningState.openingSoon,
        nextChangeMinutes: 9 * 60,
      ),
    );
    expect(
      eval(hours, saturday(10)),
      const OpeningHoursStatus(
        state: OpeningState.open,
        nextChangeMinutes: 20 * 60,
      ),
    );
    // A public holiday (e.g. a Monday) follows the second rule.
    expect(
      eval(hours, monday(11), isPublicHoliday: true),
      const OpeningHoursStatus(
        state: OpeningState.open,
        nextChangeMinutes: 20 * 60,
      ),
    );
  });

  test('a day selector applies only on those days', () {
    expect(
      eval('Mo 09:00-17:00', saturday(12)),
      const OpeningHoursStatus(state: OpeningState.closed),
    );
    expect(
      eval('Mo 09:00-17:00', monday(12)),
      const OpeningHoursStatus(
        state: OpeningState.open,
        nextChangeMinutes: 17 * 60,
      ),
    );
  });

  test('day ranges, lists and wraparound are understood', () {
    expect(eval('Mo-Fr 08:00-18:00', monday(9))!.isOpen, isTrue);
    expect(eval('Mo-Fr 08:00-18:00', saturday(9))!.isOpen, isFalse);
    expect(eval('Sa,Su 10:00-14:00', saturday(11))!.isOpen, isTrue);
    // Fr-Mo wraps past Sunday.
    expect(eval('Fr-Mo 10:00-14:00', saturday(11))!.isOpen, isTrue);
  });

  test('multiple ranges are merged, so "now" sits in one span', () {
    const String split = 'Mo 08:00-12:00,13:00-18:00';
    expect(
      eval(split, monday(10)),
      const OpeningHoursStatus(
        state: OpeningState.open,
        nextChangeMinutes: 12 * 60,
      ),
    );
    // In the lunch gap — closed, reopening within the hour.
    expect(
      eval(split, monday(12, 30)),
      const OpeningHoursStatus(
        state: OpeningState.openingSoon,
        nextChangeMinutes: 13 * 60,
      ),
    );
    expect(
      eval(split, monday(14)),
      const OpeningHoursStatus(
        state: OpeningState.open,
        nextChangeMinutes: 18 * 60,
      ),
    );
  });

  test('a later rule extending the day is merged', () {
    const String hours = 'Mo-Fr 08:00-12:00; We 08:00-18:00';
    final DateTime wednesday = DateTime(2026, 10, 28, 15);
    expect(
      eval(hours, wednesday),
      const OpeningHoursStatus(
        state: OpeningState.open,
        nextChangeMinutes: 18 * 60,
      ),
    );
  });

  test('an `off` exception closes the day', () {
    expect(
      eval('Mo-Su 10:00-18:00; Su off', DateTime(2026, 11, 1, 12))!.isOpen,
      isFalse,
    );
    // Other days are unaffected.
    expect(eval('Mo-Su 10:00-18:00; Su off', saturday(12))!.isOpen, isTrue);
  });

  test('`open` means all day', () {
    expect(eval('Mo open', monday(3))!.isOpen, isTrue);
  });

  test('crossing midnight stays open late, and opens early', () {
    expect(eval('Mo 22:00-02:00', monday(23))!.isOpen, isTrue);
    expect(eval('Mo 22:00-02:00', monday(1))!.isOpen, isTrue);
    expect(eval('Mo 22:00-02:00', monday(12))!.isOpen, isFalse);
  });

  test('month selectors are honoured (Berlin Cathedral)', () {
    const String hours =
        'Mo-Fr 09:00-18:00; Sa 09:00-17:00; Su,PH 12:00-18:00; '
        'Jun-Aug Mo-Sa 09:00-19:00; Jun-Aug Su,PH 12:00-19:00';
    // October (out of season): the base weekday rule.
    expect(
      eval(hours, DateTime(2026, 10, 27, 12, 39)),
      const OpeningHoursStatus(
        state: OpeningState.open,
        nextChangeMinutes: 18 * 60,
      ),
    );
    // July: the summer rule extends the closing time.
    expect(
      eval(hours, DateTime(2026, 7, 7, 12, 39)),
      const OpeningHoursStatus(
        state: OpeningState.open,
        nextChangeMinutes: 19 * 60,
      ),
    );
    // A summer Sunday evening is still open (until 19:00).
    expect(eval(hours, DateTime(2026, 7, 12, 18, 30))!.isOpen, isTrue);
    // A month-only rule that is out of season simply does not apply.
    expect(
      eval('Jun-Aug 09:00-17:00', DateTime(2026, 10, 27, 12))!.state,
      OpeningState.closed,
    );
    expect(
      eval('Jun-Aug 09:00-17:00', DateTime(2026, 7, 7, 12))!.isOpen,
      isTrue,
    );
  });

  test('weekly schedule reflects the season (Berlin Cathedral)', () {
    const String hours =
        'Mo-Fr 09:00-18:00; Sa 09:00-17:00; Su,PH 12:00-17:00; '
        'Jun-Aug Mo-Sa 09:00-19:00; Jun-Aug Su,PH 12:00-19:00';

    List<OpeningDay>? week(DateTime at) => weeklyOpeningHours(hours, at);
    String join(List<OpeningDay> days) =>
        days.map((OpeningDay d) => '${d.dayName}=${d.hoursLabel}').join('; ');

    expect(
      join(week(DateTime(2026, 10, 27))!),
      'Mon=09:00-18:00; Tue=09:00-18:00; Wed=09:00-18:00; Thu=09:00-18:00; '
      'Fri=09:00-18:00; Sat=09:00-17:00; Sun=12:00-17:00',
    );
    expect(
      join(week(DateTime(2026, 7, 7))!),
      'Mon=09:00-19:00; Tue=09:00-19:00; Wed=09:00-19:00; Thu=09:00-19:00; '
      'Fri=09:00-19:00; Sat=09:00-19:00; Sun=12:00-19:00',
    );
  });

  test('weekly schedule handles 24/7, off days and unknown values', () {
    final List<OpeningDay> all = weeklyOpeningHours('24/7', monday(0))!;
    expect(all, hasLength(7));
    expect(all.every((OpeningDay d) => d.isAllDay), isTrue);

    final List<OpeningDay> off = weeklyOpeningHours(
      'Mo-Su 10:00-18:00; Su off',
      monday(0),
    )!;
    expect(off.last.isClosed, isTrue);
    expect(off.first.hoursLabel, '10:00-18:00');

    expect(weeklyOpeningHours(null, monday(0)), isNull);
    expect(weeklyOpeningHours('by appointment', monday(0)), isNull);
  });

  test('unknown forms return null (we show the raw tag instead)', () {
    expect(eval(null, monday(12)), isNull);
    expect(eval('', monday(12)), isNull);
    expect(eval('Mo sunrise-sunset', monday(12)), isNull);
    expect(eval('week 1-52 Mo-Fr 09:00-17:00', monday(12)), isNull);
    expect(eval('by appointment', monday(12)), isNull);
    expect(eval('Mo 08:00-12:00; "ring bell"', monday(12)), isNull);
    expect(
      eval('Mo 8am-5pm', monday(12)),
      isNull,
      reason: 'we do not parse am/pm times',
    );
  });

  test('bounds hostile input', () {
    expect(eval('9' * 500, monday(12)), isNull);
    expect(eval('Mo 25:00-99:99', monday(12)), isNull);
  });
}
