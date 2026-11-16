import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/transit.dart';
import '../../../../state/route.dart';
import '../../../common/error_text.dart';
import '../../../common/shimmer.dart';
import '../../../design/play.dart';
import 'transit_common.dart';
import 'transit_itinerary_card.dart';

/// Step 1 of the transit flow: when to leave, what to prefer, and the list of
/// journeys. Tapping a journey opens its detail (step 2).
class TransitSection extends ConsumerWidget {
  const TransitSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RouteState state = ref.watch(routeControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TimeChips(state: state),
        const SizedBox(height: AppSpacing.sm),
        _PreferRow(state: state),
        const SizedBox(height: AppSpacing.sm),
        _RoutePreferenceRow(state: state),
        const SizedBox(height: AppSpacing.md),
        _TransitBody(state: state),
      ],
    );
  }
}

/// "Leave now / Depart at / Arrive by". Choosing a departure or arrival opens a
/// date-then-time picker; the chosen time is shown and can be changed.
class _TimeChips extends ConsumerWidget {
  const _TimeChips({required this.state});

  final RouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RouteController controller = ref.read(
      routeControllerProvider.notifier,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: PlayChip(
                  label: 'Leave now',
                  selected: state.transitTimeMode == TransitTimeMode.leaveNow,
                  onTap: () => unawaited(
                    controller.setTransitTimeOfDay(
                      TransitTimeMode.leaveNow,
                      null,
                    ),
                  ),
                ),
              ),
              for (final (TransitTimeMode mode, String label)
                  in const <(TransitTimeMode, String)>[
                    (TransitTimeMode.departAt, 'Depart at'),
                    (TransitTimeMode.arriveBy, 'Arrive by'),
                  ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: PlayChip(
                    label: label,
                    selected: state.transitTimeMode == mode,
                    onTap: () => unawaited(
                      _pickDateTime(context, ref, controller, mode),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (state.transitTimeMode != TransitTimeMode.leaveNow)
          Align(
            alignment: Alignment.centerLeft,
            child: PlayButton(
              label: transitClock(
                context,
                (state.transitTime ?? DateTime.now()).toLocal(),
              ),
              icon: PlayIcons.clock,
              variant: PlayButtonVariant.ghost,
              size: PlayButtonSize.sm,
              onPressed: () => unawaited(
                _pickDateTime(context, ref, controller, state.transitTimeMode),
              ),
            ),
          ),
      ],
    );
  }

  /// Opens the date-and-time picker and re-plans with the result.
  Future<void> _pickDateTime(
    BuildContext context,
    WidgetRef ref,
    RouteController controller,
    TransitTimeMode mode,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime initial =
        state.transitTime ?? now.add(const Duration(minutes: 5));
    final DateTime? picked = await showPlaySheet<DateTime>(
      context,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          PlaySpace.lg,
          0,
          PlaySpace.lg,
          PlaySpace.lg,
        ),
        child: _PlayDateTimePicker(initial: initial),
      ),
    );
    if (picked == null) {
      return;
    }
    await controller.setTransitTimeOfDay(mode, picked);
  }
}

/// A play date-and-time picker: a month grid over hour/minute steppers. It
/// replaces the Material `showDatePicker`/`showTimePicker` pair (the play kit
/// has no pickers of its own yet).
class _PlayDateTimePicker extends StatefulWidget {
  const _PlayDateTimePicker({required this.initial});

  final DateTime initial;

  @override
  State<_PlayDateTimePicker> createState() => _PlayDateTimePickerState();
}

class _PlayDateTimePickerState extends State<_PlayDateTimePicker> {
  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const List<String> _weekdays = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  late DateTime _value = widget.initial;
  late int _year = widget.initial.year;
  late int _month = widget.initial.month;

  void _shiftMonth(int delta) {
    final int index = _year * 12 + (_month - 1) + delta;
    setState(() {
      _year = index ~/ 12;
      _month = index % 12 + 1;
    });
  }

  void _shiftMinutes(int delta) {
    setState(() => _value = _value.add(Duration(minutes: delta)));
  }

  void _selectDay(int day) {
    setState(
      () => _value = DateTime(_year, _month, day, _value.hour, _value.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Choose a time',
          style: PlayType.title.copyWith(color: colors.ink),
        ),
        const SizedBox(height: PlaySpace.md),
        Row(
          children: <Widget>[
            PlayIconButton(
              icon: PlayIcons.back,
              variant: PlayIconButtonVariant.plain,
              size: 36,
              semanticLabel: 'Previous month',
              onPressed: () => _shiftMonth(-1),
            ),
            Expanded(
              child: Text(
                '${_months[_month - 1]} $_year',
                textAlign: TextAlign.center,
                style: PlayType.bodyStrong.copyWith(color: colors.ink),
              ),
            ),
            PlayIconButton(
              icon: PlayIcons.next,
              variant: PlayIconButtonVariant.plain,
              size: 36,
              semanticLabel: 'Next month',
              onPressed: () => _shiftMonth(1),
            ),
          ],
        ),
        const SizedBox(height: PlaySpace.xs),
        Row(
          children: <Widget>[
            for (final String weekday in _weekdays)
              Expanded(
                child: Text(
                  weekday,
                  textAlign: TextAlign.center,
                  style: PlayType.caption.copyWith(color: colors.inkMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: PlaySpace.xs),
        ..._weeks(colors),
        const SizedBox(height: PlaySpace.md),
        _TimeRow(
          label: formatClockLabel(
            _value,
            use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          ),
          onEarlier: () => _shiftMinutes(-15),
          onLater: () => _shiftMinutes(15),
        ),
        const SizedBox(height: PlaySpace.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: PlayButton(
                label: 'Cancel',
                variant: PlayButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: PlaySpace.sm),
            Expanded(
              child: PlayButton(
                label: 'Set',
                onPressed: () => Navigator.of(context).pop(_value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _weeks(PlayColors colors) {
    final DateTime first = DateTime(_year, _month, 1);
    final int daysInMonth = DateTime(_year, _month + 1, 0).day;
    final int leading = first.weekday - 1;
    final List<int> cells = <int>[
      for (int i = 0; i < leading; i++) 0,
      for (int day = 1; day <= daysInMonth; day++) day,
    ];
    while (cells.length % 7 != 0) {
      cells.add(0);
    }
    final List<Widget> rows = <Widget>[];
    for (int start = 0; start < cells.length; start += 7) {
      rows.add(
        Row(
          children: <Widget>[
            for (int i = start; i < start + 7; i++)
              Expanded(child: _dayCell(cells[i], colors)),
          ],
        ),
      );
    }
    return rows;
  }

  Widget _dayCell(int day, PlayColors colors) {
    if (day == 0) {
      return const SizedBox(height: 40);
    }
    final bool selected =
        _value.year == _year && _value.month == _month && _value.day == day;
    return PlayPressable(
      onTap: () => _selectDay(day),
      scale: 0.9,
      child: SizedBox(
        height: 40,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: selected ? colors.primary : const Color(0x00000000),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: PlayType.caption.copyWith(
                  color: selected ? colors.onPrimary : colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hour/minute stepper row inside [_PlayDateTimePicker].
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.onEarlier,
    required this.onLater,
  });

  final String label;
  final VoidCallback onEarlier;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text('Time', style: PlayType.body.copyWith(color: colors.ink)),
        ),
        PlayIconButton(
          icon: PhosphorIconsRegular.minus,
          variant: PlayIconButtonVariant.surface,
          tone: PlayTone.soft,
          size: 36,
          iconSize: 16,
          semanticLabel: 'Earlier',
          onPressed: onEarlier,
        ),
        SizedBox(
          width: 84,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: PlayType.bodyStrong.copyWith(color: colors.ink),
          ),
        ),
        PlayIconButton(
          icon: PlayIcons.add,
          variant: PlayIconButtonVariant.surface,
          tone: PlayTone.soft,
          size: 36,
          iconSize: 16,
          semanticLabel: 'Later',
          onPressed: onLater,
        ),
      ],
    );
  }
}

/// The "Prefer Bus / Subway / Train / Tram" filter chips.
class _PreferRow extends ConsumerWidget {
  const _PreferRow({required this.state});

  final RouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LabelledChips(
      label: 'Prefer',
      children: <Widget>[
        for (final TransitModeGroup group in const <TransitModeGroup>[
          TransitModeGroup.bus,
          TransitModeGroup.subway,
          TransitModeGroup.train,
          TransitModeGroup.tram,
        ])
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: PlayChip(
              icon: transitModeIcon(group.modes.first),
              label: group.label,
              selected: group.modes.every(state.transitModes.contains),
              onTap: () => unawaited(
                ref
                    .read(routeControllerProvider.notifier)
                    .toggleTransitGroup(group),
              ),
            ),
          ),
      ],
    );
  }
}

/// The "Fewer transfers / Less walking" ranking chips.
class _RoutePreferenceRow extends ConsumerWidget {
  const _RoutePreferenceRow({required this.state});

  final RouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RouteController controller = ref.read(
      routeControllerProvider.notifier,
    );
    return _LabelledChips(
      label: 'Route',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: PlayChip(
            label: 'Fewer transfers',
            selected: state.fewerTransfers,
            onTap: () =>
                unawaited(controller.setFewerTransfers(!state.fewerTransfers)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: PlayChip(
            label: 'Less walking',
            selected: state.lessWalking,
            onTap: () =>
                unawaited(controller.setLessWalking(!state.lessWalking)),
          ),
        ),
      ],
    );
  }
}

class _LabelledChips extends StatelessWidget {
  const _LabelledChips({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: PlayType.bodyStrong.copyWith(color: colors.ink),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: children),
          ),
        ),
      ],
    );
  }
}

class _TransitBody extends ConsumerWidget {
  const _TransitBody({required this.state});

  final RouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.status) {
      case RouteStatus.loading:
        return const _TransitLoadingSkeleton();
      case RouteStatus.error:
        final ({IconData icon, String text}) presentation = errorPresentation(
          state.error,
          fallback: 'Could not find a journey',
        );
        return _TransitError(
          icon: presentation.icon,
          message: presentation.text,
          onRetry: () =>
              unawaited(ref.read(routeControllerProvider.notifier).retry()),
        );
      case RouteStatus.idle:
        return const SizedBox.shrink();
      case RouteStatus.data:
        if (state.itineraries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('No journeys found for this time.'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < state.itineraries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TransitItineraryCard(
                  itinerary: state.itineraries[i],
                  selected: i == state.selectedItineraryIndex,
                  // Step 2: open the journey detail.
                  onTap: () => ref
                      .read(routeControllerProvider.notifier)
                      .openTransitDetail(i),
                ),
              ),
          ],
        );
    }
  }
}

class _TransitError extends StatelessWidget {
  const _TransitError({
    required this.message,
    required this.onRetry,
    this.icon = PlayIcons.error,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Icon(icon, color: PlayColors.of(context).inkFaint),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          PlayButton(
            label: 'Retry',
            icon: PlayIcons.refresh,
            variant: PlayButtonVariant.ghost,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// The shimmering stand-in shown while public-transport journeys are being
/// planned: a few journey-card blocks in place of the list.
class _TransitLoadingSkeleton extends StatelessWidget {
  const _TransitLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            const ShimmerBox(height: 88, radius: 12),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
