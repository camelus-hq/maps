/// A reader for OpenStreetMap's `opening_hours` tag.
///
/// Covers the common forms an app needs to answer "are you open *now*": weekly
/// day selectors (`Mo-Fr`, `PH,Sa,Su`), month selectors (`Jun-Aug Mo-Sa …`),
/// time ranges (`08:00-20:00`), 24/7, `off`/`open`, and multiple rules
/// separated by `;` or `||`. Anything outside that subset — sunrise/sunset,
/// week numbers, day-of-month, comments, extended hours — returns `null`
/// ("unknown"), so the caller shows the raw tag rather than a verdict it cannot
/// stand behind. Pure Dart: no Flutter imports.
///
/// `PH`/`SH` (public/school holidays) are parsed, but we carry no holiday
/// calendar: the caller says whether today is one, and the default is "no".
library;

/// How a place's hours read at the moment they were evaluated.
enum OpeningState {
  /// Open, and not about to close.
  open,

  /// Open, but closing within the "soon" window.
  closingSoon,

  /// Closed, but opening within the "soon" window.
  openingSoon,

  /// Closed, with nothing opening soon.
  closed,
}

/// The default "soon" window: an hour.
const int defaultOpeningSoonMinutes = 60;

/// The verdict for an `opening_hours` value at a moment in time.
class OpeningHoursStatus {
  const OpeningHoursStatus({required this.state, this.nextChangeMinutes});

  final OpeningState state;

  /// Minutes since midnight when the state next flips — the closing time when
  /// open, the next opening time when closed. `null` when there is no change
  /// today (e.g. `24/7`, or it reopens another day).
  final int? nextChangeMinutes;

  /// Whether the place is open right now (including "closing soon").
  bool get isOpen =>
      state == OpeningState.open || state == OpeningState.closingSoon;

  @override
  bool operator ==(Object other) =>
      other is OpeningHoursStatus &&
      other.state == state &&
      other.nextChangeMinutes == nextChangeMinutes;

  @override
  int get hashCode => Object.hash(state, nextChangeMinutes);

  @override
  String toString() => 'OpeningHoursStatus(${state.name}, $nextChangeMinutes)';
}

/// Evaluates [hours] at [at] (only the weekday and time-of-day are used).
///
/// Returns `null` when [hours] is empty or not one of the understood forms.
/// [isPublicHoliday]/[isSchoolHoliday] feed the `PH`/`SH` selectors — we have no
/// holiday calendar yet, so they default to `false`.
OpeningHoursStatus? evaluateOpeningHours(
  String? hours,
  DateTime at, {
  bool isPublicHoliday = false,
  bool isSchoolHoliday = false,
  int soonMinutes = defaultOpeningSoonMinutes,
}) {
  if (hours == null) {
    return null;
  }
  final String value = hours.trim();
  if (value.isEmpty || value.length > 400) {
    return null;
  }
  // A construct we do not model makes the whole value ambiguous — bail rather
  // than guess.
  if (_unsupported.hasMatch(value)) {
    return null;
  }

  final int weekday = at.weekday; // 1 = Monday … 7 = Sunday.
  final int month = at.month; // 1 = January … 12 = December.
  final int now = at.hour * 60 + at.minute;

  final List<_Rule>? rules = _parseRules(value);
  if (rules == null) {
    return null;
  }

  final List<_Rule> applicable = <_Rule>[
    for (final _Rule rule in rules)
      if (rule.matches(
        weekday,
        month,
        publicHoliday: isPublicHoliday,
        schoolHoliday: isSchoolHoliday,
      ))
        rule,
  ];
  if (applicable.isEmpty || applicable.any((_Rule rule) => rule.off)) {
    // No rule applies (closed all day), or an `off` exception carves it out.
    return const OpeningHoursStatus(state: OpeningState.closed);
  }

  final List<_Span> spans = _merge(<_Span>[
    for (final _Rule rule in applicable) ...rule.spans,
  ]);
  if (spans.isEmpty) {
    return const OpeningHoursStatus(state: OpeningState.closed);
  }

  for (final _Span span in spans) {
    if (span.covers(now)) {
      final int? closes = span.end >= _minutesPerDay ? null : span.end;
      final bool soon = closes != null && closes - now <= soonMinutes;
      return OpeningHoursStatus(
        state: soon ? OpeningState.closingSoon : OpeningState.open,
        nextChangeMinutes: closes,
      );
    }
  }

  int? opens;
  for (final _Span span in spans) {
    if (span.start > now && (opens == null || span.start < opens)) {
      opens = span.start;
    }
  }
  final bool soon = opens != null && opens - now <= soonMinutes;
  return OpeningHoursStatus(
    state: soon ? OpeningState.openingSoon : OpeningState.closed,
    nextChangeMinutes: opens,
  );
}

const int _minutesPerDay = 24 * 60;

/// One day of a place's weekly opening hours.
class OpeningDay {
  const OpeningDay({required this.weekday, required this.ranges});

  /// 1 = Monday … 7 = Sunday.
  final int weekday;

  /// The open ranges, sorted and merged; empty means closed all day.
  final List<OpeningRange> ranges;

  bool get isClosed => ranges.isEmpty;

  /// Whether the day is open around the clock.
  bool get isAllDay =>
      ranges.length == 1 &&
      ranges.single.start == 0 &&
      ranges.single.end >= _minutesPerDay;

  /// The short day name (`Mon` … `Sun`), or `''` for an invalid weekday.
  String get dayName => _dayNames[weekday] ?? '';

  /// `09:00-18:00`, `08:00-12:00, 13:00-18:00`, `24 hours` or `Closed`.
  String get hoursLabel {
    if (isClosed) {
      return 'Closed';
    }
    if (isAllDay) {
      return '24 hours';
    }
    return ranges
        .map((OpeningRange r) => '${_clock(r.start)}-${_clock(r.end)}')
        .join(', ');
  }

  static const Map<int, String> _dayNames = <int, String>{
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };
}

/// A single opening range in minutes since midnight.
class OpeningRange {
  const OpeningRange(this.start, this.end);

  final int start;
  final int end;
}

/// The full weekly schedule for [hours] (Monday … Sunday), for the place's
/// Overview tab.
///
/// The schedule reflects the season of [at] (month selectors); `PH`/`SH` rules
/// count as "not today" because we have no holiday calendar. Returns `null` when
/// [hours] is empty or not one of the understood forms (the caller then shows
/// the raw tag instead).
List<OpeningDay>? weeklyOpeningHours(String? hours, DateTime at) {
  if (hours == null) {
    return null;
  }
  final String value = hours.trim();
  if (value.isEmpty || value.length > 400 || _unsupported.hasMatch(value)) {
    return null;
  }
  final List<_Rule>? rules = _parseRules(value);
  if (rules == null) {
    return null;
  }

  final int month = at.month;
  final List<OpeningDay> days = <OpeningDay>[];
  for (int weekday = 1; weekday <= 7; weekday++) {
    final List<_Rule> applicable = <_Rule>[
      for (final _Rule rule in rules)
        if (rule.matches(
          weekday,
          month,
          publicHoliday: false,
          schoolHoliday: false,
        ))
          rule,
    ];
    if (applicable.isEmpty || applicable.any((_Rule rule) => rule.off)) {
      days.add(OpeningDay(weekday: weekday, ranges: const <OpeningRange>[]));
      continue;
    }
    final List<_Span> merged = _merge(<_Span>[
      for (final _Rule rule in applicable) ...rule.spans,
    ]);
    days.add(
      OpeningDay(
        weekday: weekday,
        ranges: <OpeningRange>[
          for (final _Span span in merged) OpeningRange(span.start, span.end),
        ],
      ),
    );
  }
  return days;
}

/// Splits a value into rules, or `null` when one is unparsable/empty.
List<_Rule>? _parseRules(String value) {
  final List<_Rule> rules = <_Rule>[];
  for (final String token in value.split(RegExp(r';|\|\|'))) {
    final String rule = token.trim();
    if (rule.isEmpty) {
      continue;
    }
    final _Rule? parsed = _Rule.parse(rule);
    if (parsed == null) {
      return null;
    }
    rules.add(parsed);
  }
  return rules.isEmpty ? null : rules;
}

String _clock(int minutes) {
  final int h = (minutes ~/ 60).clamp(0, 24);
  final int m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

final RegExp _unsupported = RegExp(
  r'(sunrise|sunset|dawn|dusk|\bweek\b|"|\+|\[|\])',
  caseSensitive: false,
);

/// One rule: optional month and day selectors, then `off`/`open`/time ranges.
class _Rule {
  const _Rule({
    required this.days,
    required this.spans,
    required this.off,
    this.months = const <int>{},
  });

  final _DaySelector days;
  final List<_Span> spans;
  final bool off;

  /// Months (1..12) the rule applies to; empty means all.
  final Set<int> months;

  bool matches(
    int weekday,
    int month, {
    required bool publicHoliday,
    required bool schoolHoliday,
  }) =>
      (months.isEmpty || months.contains(month)) &&
      days.matches(
        weekday,
        publicHoliday: publicHoliday,
        schoolHoliday: schoolHoliday,
      );

  static const Map<String, int> _monthNames = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static final RegExp _daySelectorRe = RegExp(
    r'^((?:Mo|Tu|We|Th|Fr|Sa|Su|PH|SH)'
    r'(?:\s*-\s*(?:Mo|Tu|We|Th|Fr|Sa|Su))?'
    r'(?:\s*,\s*(?:Mo|Tu|We|Th|Fr|Sa|Su|PH|SH)'
    r'(?:\s*-\s*(?:Mo|Tu|We|Th|Fr|Sa|Su))?)*)\s+',
    caseSensitive: false,
  );

  static final RegExp _monthSelectorRe = RegExp(
    r'^((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'
    r'(?:\s*-\s*(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))?'
    r'(?:\s*,\s*(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'
    r'(?:\s*-\s*(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))?)*)\s+',
    caseSensitive: false,
  );

  static _Rule? parse(String rule) {
    if (rule.toLowerCase() == '24/7') {
      return const _Rule(
        days: _DaySelector.all(),
        spans: <_Span>[_Span(0, _minutesPerDay)],
        off: false,
      );
    }
    String rest = rule;
    Set<int> months = const <int>{};
    final RegExpMatch? monthMatch = _monthSelectorRe.firstMatch(rest);
    if (monthMatch != null) {
      final Set<int>? parsed = _parseMonths(monthMatch.group(1)!);
      if (parsed == null) {
        return null;
      }
      months = parsed;
      rest = rest.substring(monthMatch.end).trim();
    }
    _DaySelector days = const _DaySelector.all();
    final RegExpMatch? selector = _daySelectorRe.firstMatch(rest);
    if (selector != null) {
      final _DaySelector? parsed = _DaySelector.parse(selector.group(1)!);
      if (parsed == null) {
        return null;
      }
      days = parsed;
      rest = rest.substring(selector.end).trim();
    }
    if (rest.isEmpty) {
      return null;
    }
    final String lower = rest.toLowerCase();
    if (lower == 'off') {
      return _Rule(
        days: days,
        spans: const <_Span>[],
        off: true,
        months: months,
      );
    }
    if (lower == 'open') {
      return _Rule(
        days: days,
        spans: const <_Span>[_Span(0, _minutesPerDay)],
        off: false,
        months: months,
      );
    }
    final List<_Span> spans = <_Span>[];
    for (final String piece in rest.split(',')) {
      final List<_Span>? parsed = _Span.parse(piece.trim());
      if (parsed == null) {
        return null;
      }
      spans.addAll(parsed);
    }
    if (spans.isEmpty) {
      return null;
    }
    return _Rule(days: days, spans: spans, off: false, months: months);
  }

  static Set<int>? _parseMonths(String spec) {
    final Set<int> months = <int>{};
    for (final String part in spec.split(',')) {
      final List<String> bounds = part.trim().toLowerCase().split('-');
      final int? start = _monthNames[bounds.first];
      if (start == null || bounds.length > 2) {
        return null;
      }
      if (bounds.length == 1) {
        months.add(start);
        continue;
      }
      final int? end = _monthNames[bounds[1]];
      if (end == null) {
        return null;
      }
      // Inclusive, wrapping past December when needed (e.g. `Nov-Feb`).
      int month = start;
      for (int i = 0; i < 12; i++) {
        months.add(month);
        if (month == end) {
          break;
        }
        month = month % 12 + 1;
      }
    }
    return months.isEmpty ? null : months;
  }
}

/// Which days a rule applies to: weekdays, and/or PH/SH.
class _DaySelector {
  const _DaySelector({
    required this.weekdays,
    this.publicHoliday = false,
    this.schoolHoliday = false,
  });

  const _DaySelector.all()
    : weekdays = const <int>{1, 2, 3, 4, 5, 6, 7},
      publicHoliday = false,
      schoolHoliday = false;

  final Set<int> weekdays;
  final bool publicHoliday;
  final bool schoolHoliday;

  bool matches(
    int weekday, {
    required bool publicHoliday,
    required bool schoolHoliday,
  }) =>
      weekdays.contains(weekday) ||
      (this.publicHoliday && publicHoliday) ||
      (this.schoolHoliday && schoolHoliday);

  static const Map<String, int> _weekdays = <String, int>{
    'mo': 1,
    'tu': 2,
    'we': 3,
    'th': 4,
    'fr': 5,
    'sa': 6,
    'su': 7,
  };

  static _DaySelector? parse(String spec) {
    final Set<int> days = <int>{};
    bool publicHoliday = false;
    bool schoolHoliday = false;
    for (final String part in spec.split(',')) {
      final String token = part.trim().toLowerCase();
      if (token.isEmpty) {
        return null;
      }
      if (token == 'ph') {
        publicHoliday = true;
        continue;
      }
      if (token == 'sh') {
        schoolHoliday = true;
        continue;
      }
      final List<String> bounds = token.split('-');
      final int? start = _weekdays[bounds.first];
      if (start == null || bounds.length > 2) {
        return null;
      }
      if (bounds.length == 1) {
        days.add(start);
        continue;
      }
      final int? end = _weekdays[bounds[1]];
      if (end == null) {
        return null;
      }
      // Inclusive, wrapping past Sunday when needed (e.g. `Fr-Mo`).
      int day = start;
      for (int i = 0; i < 7; i++) {
        days.add(day);
        if (day == end) {
          break;
        }
        day = day % 7 + 1;
      }
    }
    if (days.isEmpty && !publicHoliday && !schoolHoliday) {
      return null;
    }
    return _DaySelector(
      weekdays: days,
      publicHoliday: publicHoliday,
      schoolHoliday: schoolHoliday,
    );
  }
}

/// A half-open time range `[start, end)` in minutes since midnight.
class _Span {
  const _Span(this.start, this.end);

  final int start;
  final int end;

  bool covers(int minute) => minute >= start && minute < end;

  /// Parses `HH:MM-HH:MM`. A range that crosses midnight is split into two so
  /// every span has `start < end`. Returns `null` when unparsable, or an empty
  /// list for a zero-length range (which we simply ignore).
  static List<_Span>? parse(String piece) {
    final RegExpMatch? match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$',
    ).firstMatch(piece);
    if (match == null) {
      return null;
    }
    final int? start = _minutes(match.group(1)!, match.group(2)!);
    final int? end = _minutes(match.group(3)!, match.group(4)!);
    if (start == null || end == null) {
      return null;
    }
    if (start == end) {
      return const <_Span>[];
    }
    if (end > start) {
      return <_Span>[_Span(start, end)];
    }
    return <_Span>[_Span(start, _minutesPerDay), if (end > 0) _Span(0, end)];
  }

  static int? _minutes(String hour, String minute) {
    final int? h = int.tryParse(hour);
    final int? m = int.tryParse(minute);
    if (h == null || m == null || h < 0 || h > 24 || m < 0 || m > 59) {
      return null;
    }
    if (h == 24 && m != 0) {
      return null;
    }
    return h * 60 + m;
  }
}

/// Sorts and merges overlapping/adjacent spans so "now" falls in exactly one.
List<_Span> _merge(List<_Span> spans) {
  if (spans.isEmpty) {
    return const <_Span>[];
  }
  final List<_Span> sorted = <_Span>[...spans]
    ..sort((_Span a, _Span b) => a.start.compareTo(b.start));
  final List<_Span> merged = <_Span>[];
  _Span current = sorted.first;
  for (int i = 1; i < sorted.length; i++) {
    final _Span span = sorted[i];
    if (span.start <= current.end) {
      if (span.end > current.end) {
        current = _Span(current.start, span.end);
      }
    } else {
      merged.add(current);
      current = span;
    }
  }
  merged.add(current);
  return merged;
}
