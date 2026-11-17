import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/lat_lon.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/recent_search.dart';
import '../../../state/place.dart';
import '../../../state/route.dart';
import '../../../state/saved_places.dart';
import '../../../state/search.dart';
import '../../../state/settings.dart';
import '../../common/error_text.dart';
import '../../common/navigation.dart';
import '../../common/place_result_icon.dart';
import '../../design/play.dart';

/// The search-style place picker for a directions endpoint (start, stop or
/// destination).
///
/// Opened by `route.editEndpoint`; the endpoint being edited lives in
/// [RouteState.editingEndpoint]. The empty state offers "Your location",
/// "Choose on map" (a long-press on the map), the saved places and recent
/// searches; typing runs the normal search and a result fills the endpoint.
class EndpointPickerScreen extends ConsumerStatefulWidget {
  const EndpointPickerScreen({super.key});

  @override
  ConsumerState<EndpointPickerScreen> createState() =>
      _EndpointPickerScreenState();
}

class _EndpointPickerScreenState extends ConsumerState<EndpointPickerScreen> {
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start from a clean slate: drop any results left by an earlier search.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit(String value) {
    unawaited(ref.read(searchControllerProvider.notifier).submit(value));
  }

  /// Fills [target] with [place] and returns to the map.
  void _choose(RouteEndpointTarget target, Place place) {
    unawaited(
      ref.read(routeControllerProvider.notifier).applyEndpoint(target, place),
    );
    _close();
  }

  void _useCurrentLocation(RouteEndpointTarget target) {
    unawaited(
      ref.read(routeControllerProvider.notifier).useCurrentLocationFor(target),
    );
    _close();
  }

  /// Arms the map so the next long-press fills [target] and returns to it.
  void _chooseOnMap(RouteEndpointTarget target) {
    ref.read(routeControllerProvider.notifier).beginPick(target);
    _close();
  }

  void _close() {
    ref.read(routeControllerProvider.notifier).closeEndpointPicker();
    ref.read(searchControllerProvider.notifier).reset();
    if (mounted) {
      popOrHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final RouteEndpointTarget target =
        ref.watch(routeControllerProvider).editingEndpoint ??
        const RouteEndpointTarget.destination();
    final SearchState state = ref.watch(searchControllerProvider);
    return PlayScaffold(
      child: Column(
        children: <Widget>[
          _SearchField(
            controller: _text,
            hint: _hint(target),
            onChanged: ref.read(searchControllerProvider.notifier).queryChanged,
            onSubmitted: _submit,
            onBack: _close,
            onClear: () {
              _text.clear();
              ref.read(searchControllerProvider.notifier).reset();
            },
            showClear: state.query.isNotEmpty,
          ),
          Expanded(child: _body(target, state)),
        ],
      ),
    );
  }

  static String _hint(RouteEndpointTarget target) => switch (target.field) {
    RouteEndpointField.origin => 'Choose a start',
    RouteEndpointField.destination => 'Choose a destination',
    RouteEndpointField.stop =>
      target.stopIndex == null ? 'Add a stop' : 'Change stop',
  };

  Widget _body(RouteEndpointTarget target, SearchState state) {
    switch (state.status) {
      case SearchStatus.loading:
        return const Center(child: PlaySpinner());
      case SearchStatus.error:
        final ({IconData icon, String text}) presentation = errorPresentation(
          state.error,
          fallback: 'Search is unavailable right now.',
        );
        return _Message(
          icon: presentation.icon,
          text: presentation.text,
          onRetry: state.query.isEmpty ? null : () => _submit(state.query),
        );
      case SearchStatus.idle:
        return _emptyState(target);
      case SearchStatus.data:
        if (state.results.isEmpty) {
          return const _Message(
            icon: PlayIcons.unsupported,
            text: 'No results',
          );
        }
        return _resultsList(target, state.results);
    }
  }

  Widget _emptyState(RouteEndpointTarget target) {
    final AsyncValue<List<Place>> saved = ref.watch(bookmarksProvider);
    final List<RecentSearch> recent = ref.watch(recentSearchesProvider);
    return ListView(
      children: <Widget>[
        PlayRow(
          icon: PlayIcons.locate,
          label: 'Your location',
          onTap: () => _useCurrentLocation(target),
        ),
        PlayRow(
          icon: PlayIcons.place,
          label: 'Choose on map',
          subtitle: 'Long-press the map',
          onTap: () => _chooseOnMap(target),
        ),
        const PlayDivider(),
        ...saved.maybeWhen<List<Widget>>(
          data: (List<Place> places) => places.isEmpty
              ? const <Widget>[]
              : <Widget>[
                  const _SectionHeader('Saved'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final Place place in places.take(4))
                          _SavedTile(
                            place: place,
                            onTap: () => _choose(target, place),
                          ),
                      ],
                    ),
                  ),
                  const PlayDivider(),
                ],
          orElse: () => const <Widget>[],
        ),
        const _SectionHeader('Recent'),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Text('No recent searches yet'),
          )
        else
          for (final RecentSearch entry in recent)
            switch (entry) {
              RecentPlaceSearch(place: final Place place) => PlayRow(
                icon: placeResultIcon(place.category),
                label: place.name,
                subtitle: place.address,
                onTap: () => _choose(target, place),
              ),
              RecentTextSearch(text: final String text) => PlayRow(
                icon: PlayIcons.recent,
                label: text,
                onTap: () {
                  _text.text = text;
                  _submit(text);
                },
              ),
            },
      ],
    );
  }

  Widget _resultsList(RouteEndpointTarget target, List<Place> results) {
    final LatLon? from = ref.watch(userLocationProvider).value;
    final bool imperial = ref.watch(imperialUnitsProvider);
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (BuildContext context, int index) =>
          const PlayDivider(),
      itemBuilder: (BuildContext context, int index) {
        final Place place = results[index];
        final String? category = place.category;
        final String? address = place.address;
        final List<String> detail = <String>[?category, ?address];
        if (from != null) {
          detail.add(
            formatDistance(place.position.distanceTo(from), imperial: imperial),
          );
        }
        return PlayRow(
          icon: placeResultIcon(place.category),
          label: place.name,
          subtitle: detail.isEmpty ? null : detail.join(' · '),
          onTap: () => _choose(target, place),
        );
      },
    );
  }
}

/// The rounded search field pinned at the top of the picker.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onBack,
    required this.onClear,
    required this.showClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: PlayTextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        hint: hint,
        clearable: false,
        leading: PlayIconButton(
          icon: PlayIcons.back,
          variant: PlayIconButtonVariant.plain,
          size: 40,
          semanticLabel: 'Back',
          onPressed: onBack,
        ),
        trailing: showClear
            ? PlayIconButton(
                icon: PlayIcons.close,
                variant: PlayIconButtonVariant.plain,
                size: 40,
                iconSize: 18,
                semanticLabel: 'Clear',
                onPressed: onClear,
              )
            : null,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: PlayType.bodyStrong.copyWith(color: PlayColors.of(context).ink),
      ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final String? address = place.address;
    return SizedBox(
      width: 160,
      child: PlaySurface(
        radius: AppSpacing.sheetRadius,
        padding: const EdgeInsets.all(AppSpacing.sm),
        shadow: PlayShadow.none,
        borderWidth: 1,
        onTap: onTap,
        child: Row(
          children: <Widget>[
            PlayAvatar(
              label: place.name,
              icon: PlayIcons.saved,
              size: 32,
              tone: PlayTone.soft,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlayType.body.copyWith(color: colors.ink),
                  ),
                  if (address != null)
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PlayType.caption.copyWith(color: colors.inkMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 44, color: colors.inkFaint),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: PlayType.body.copyWith(color: colors.inkMuted),
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            PlayButton(
              label: 'Retry',
              icon: PlayIcons.refresh,
              variant: PlayButtonVariant.ghost,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
