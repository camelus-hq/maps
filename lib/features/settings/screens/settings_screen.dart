import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ndk_flutter/ndk_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/legal_links.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/app_update.dart';
import '../../../domain/entities/friend.dart';
import '../../../domain/entities/push.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/config.dart';
import '../../../state/ports.dart';
import '../../../state/push_notifications.dart';
import '../../../state/settings.dart';
import '../../../state/social.dart';
import '../../../state/update.dart';
import '../../design/play.dart';

/// Functional settings: account, distance units, theme, search provider,
/// developer options, app update and about — all in the play style.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final AppConfig config = ref.watch(appConfigProvider);
    final bool hasMapboxToken = config.hasMapboxToken;
    final bool hasCamelusToken = config.hasCamelusToken;
    const EdgeInsets pad = EdgeInsets.symmetric(horizontal: PlaySpace.xs);
    return PlayScaffold(
      appBar: const PlayAppBar(title: 'Settings'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          PlaySpace.md,
          0,
          PlaySpace.md,
          PlaySpace.xxl,
        ),
        children: <Widget>[
          const _Section('Account'),
          const _AccountTile(),
          const _Section('Distance units'),
          Padding(
            padding: pad,
            child: PlaySegmented<DistanceUnit>(
              selected: settings.unit,
              onChanged: (DistanceUnit unit) =>
                  unawaited(ref.read(settingsProvider.notifier).setUnit(unit)),
              segments: const <PlaySegment<DistanceUnit>>[
                PlaySegment<DistanceUnit>(
                  value: DistanceUnit.metric,
                  label: 'Metric',
                ),
                PlaySegment<DistanceUnit>(
                  value: DistanceUnit.imperial,
                  label: 'Imperial',
                ),
              ],
            ),
          ),
          const _Section('Theme'),
          Padding(
            padding: pad,
            child: PlaySegmented<AppThemeMode>(
              selected: settings.theme,
              onChanged: (AppThemeMode mode) =>
                  unawaited(ref.read(settingsProvider.notifier).setTheme(mode)),
              segments: const <PlaySegment<AppThemeMode>>[
                PlaySegment<AppThemeMode>(
                  value: AppThemeMode.system,
                  label: 'System',
                ),
                PlaySegment<AppThemeMode>(
                  value: AppThemeMode.light,
                  label: 'Light',
                ),
                PlaySegment<AppThemeMode>(
                  value: AppThemeMode.dark,
                  label: 'Dark',
                ),
              ],
            ),
          ),
          const _Section('Search provider'),
          Padding(
            padding: pad,
            child: Column(
              children: <Widget>[
                _BackendRow(
                  value: SearchBackend.mapbox,
                  label: 'Mapbox',
                  subtitle: hasMapboxToken
                      ? 'Mapbox Geocoding and Search Box'
                      : 'Needs an access token — OpenStreetMap is used instead',
                ),
                _BackendRow(
                  value: SearchBackend.openstreetmap,
                  label: 'OpenStreetMap',
                  subtitle: 'Photon search and Overpass places (no account)',
                ),
                _BackendRow(
                  value: SearchBackend.camelus,
                  label: 'Camelus',
                  subtitle: hasCamelusToken
                      ? 'Photon, Overpass, Valhalla and transit via camelus.app'
                      : 'Needs an API key — OpenStreetMap is used instead',
                ),
              ],
            ),
          ),
          const _Section('Notifications'),
          Padding(
            padding: pad,
            child: PlaySegmented<PushTransport>(
              selected: settings.pushTransport,
              onChanged: (PushTransport transport) => unawaited(
                ref.read(settingsProvider.notifier).setPushTransport(transport),
              ),
              segments: <PlaySegment<PushTransport>>[
                const PlaySegment<PushTransport>(
                  value: PushTransport.firebase,
                  label: 'Firebase',
                ),
                const PlaySegment<PushTransport>(
                  value: PushTransport.off,
                  label: 'Off',
                ),
              ],
            ),
          ),
          Padding(
            padding: pad,
            child: PlayRow(
              icon: PlayIcons.notifications,
              label: 'Push status',
              subtitle: _pushStatusText(ref.watch(pushStatusProvider)),
              subtitleMaxLines: 3,
              // Tapping re-runs the registration sync, so a transient failure
              // (no token yet, server unreachable) can be retried in place.
              onTap: () =>
                  unawaited(ref.read(pushStatusProvider.notifier).refresh()),
              showChevron: false,
            ),
          ),
          const _Section('Recent trips'),
          const PlayRow(
            icon: PlayIcons.route,
            label: 'Trips to keep',
            subtitle: 'The oldest recorded trips are deleted automatically',
            showChevron: false,
          ),
          Padding(
            padding: pad,
            child: PlaySegmented<int>(
              selected: settings.recentTripsLimit,
              onChanged: (int limit) => unawaited(
                ref.read(settingsProvider.notifier).setRecentTripsLimit(limit),
              ),
              segments: <PlaySegment<int>>[
                for (final int limit in recentTripsLimits)
                  PlaySegment<int>(value: limit, label: '$limit'),
              ],
            ),
          ),
          const _Section('Developer'),
          PlayRow(
            icon: PlayIcons.code,
            label: 'Show all OpenStreetMap tags',
            subtitle: 'List every raw OSM tag on the place details sheet',
            showChevron: false,
            onTap: () => unawaited(
              ref
                  .read(settingsProvider.notifier)
                  .setShowOsmTags(!settings.showOsmTags),
            ),
            trailing: PlaySwitch(
              value: settings.showOsmTags,
              semanticLabel: 'Show all OpenStreetMap tags',
              onChanged: (bool value) => unawaited(
                ref.read(settingsProvider.notifier).setShowOsmTags(value),
              ),
            ),
          ),
          const _Section('App update'),
          const _AppUpdateTile(),
          const _Section('Data'),
          PlayRow(
            icon: PlayIcons.recent,
            label: 'Clear recent searches',
            showChevron: false,
            onTap: () async {
              await ref.read(placesRepositoryProvider).clearRecentSearches();
              if (context.mounted) {
                showPlayToast(context, 'Recent searches cleared');
              }
            },
          ),
          PlayRow(
            icon: PlayIcons.info,
            label: 'About OpenMaps',
            showChevron: false,
            onTap: () => _showAbout(context, ref),
          ),
          const PlayRow(
            icon: PlayIcons.cloudOff,
            label: 'Offline',
            subtitle: 'Searches and directions need a connection',
            showChevron: false,
            enabled: false,
          ),
          const _Section('Legal'),
          PlayRow(
            icon: PlayIcons.globe,
            label: 'Terms of Service',
            showChevron: false,
            onTap: () => unawaited(
              ref.read(externalActionsProvider).openWebsite(LegalLinks.terms),
            ),
          ),
          PlayRow(
            icon: PlayIcons.lock,
            label: 'Privacy Policy',
            showChevron: false,
            onTap: () => unawaited(
              ref.read(externalActionsProvider).openWebsite(LegalLinks.privacy),
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context, WidgetRef ref) {
    final AppVersion version =
        ref.read(installedVersionProvider).value ?? AppVersion.unknown;
    unawaited(
      showPlaySheet<void>(
        context,
        builder: (BuildContext context) => _AboutSheet(
          version: version.isKnown ? version.versionName : '0.1.0',
        ),
      ),
    );
  }
}

/// A single search-provider choice row.
class _BackendRow extends ConsumerWidget {
  const _BackendRow({
    required this.value,
    required this.label,
    required this.subtitle,
  });

  final SearchBackend value;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SearchBackend selected = ref.watch(
      settingsProvider.select((AppSettings s) => s.searchBackend),
    );
    return PlayRow(
      leading: PlayRadio(selected: value == selected),
      label: label,
      subtitle: subtitle,
      showChevron: false,
      onTap: () => unawaited(
        ref.read(settingsProvider.notifier).setSearchBackend(value),
      ),
    );
  }
}

/// The Nostr account: who is signed in (profile picture + name) and a way out.
///
/// Signing in happens on `/profile`; this row shows the current identity and
/// dispatches the same `social.logout` command as the profile screen, so the
/// behaviour is identical and drivable by agents.
class _AccountTile extends ConsumerWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? pubkey = ref.watch(nostrPubkeyProvider).value;
    if (pubkey == null) {
      return PlayRow(
        icon: PlayIcons.user,
        label: 'Not signed in',
        subtitle: 'Sign in to share your live location',
        onTap: () => context.push('/profile'),
      );
    }
    final Friend? profile = ref.watch(myProfileProvider).value;
    final NdkFlutter? ndkFlutter = ref.watch(ndkFlutterProvider);
    final String name = profile?.label ?? 'Signed in';
    final String npub = ndkFlutter?.formatNpub(pubkey) ?? _shortPubkey(pubkey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PlayRow(
          leading: PlayAvatar(
            label: name,
            imageUrl: profile?.pictureUrl,
            size: 40,
            tone: PlayTone.soft,
          ),
          label: name,
          subtitle: npub,
          showChevron: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PlaySpace.xs,
            PlaySpace.sm,
            PlaySpace.xs,
            PlaySpace.xs,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: PlayButton(
              label: 'Sign out',
              icon: PlayIcons.signOut,
              variant: PlayButtonVariant.ghost,
              size: PlayButtonSize.sm,
              onPressed: () => unawaited(_signOut(context, ref)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref
        .read(commandRegistryProvider)
        .dispatch('social.logout', const <String, Object?>{});
    if (context.mounted) {
      showPlayToast(context, 'Signed out');
    }
  }

  static String _shortPubkey(String pubkey) =>
      pubkey.length <= 16 ? pubkey : '${pubkey.substring(0, 12)}…';
}

class _AppUpdateTile extends ConsumerWidget {
  const _AppUpdateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UpdateState update = ref.watch(updateControllerProvider);
    final AsyncValue<AppVersion> installed = ref.watch(
      installedVersionProvider,
    );
    final AppVersion version = update.installed.isKnown
        ? update.installed
        : (installed.value ?? AppVersion.unknown);
    final String label = !version.isKnown
        ? 'Unknown'
        : version.versionName.isEmpty
        ? 'Version code ${version.versionCode}'
        : '${version.versionName} (${version.versionCode})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PlayRow(
          icon: PlayIcons.device,
          label: 'Installed version',
          subtitle: label,
          showChevron: false,
        ),
        ..._status(context, ref, update),
      ],
    );
  }

  List<Widget> _status(
    BuildContext context,
    WidgetRef ref,
    UpdateState update,
  ) {
    final AppRelease? release = update.release;
    if (update.installing) {
      return <Widget>[
        PlayRow(
          icon: PlayIcons.download,
          label: 'Installing the update…',
          showChevron: false,
          trailing: SizedBox(
            width: 96,
            child: PlayProgress(
              value: update.progress > 0 && update.progress < 1
                  ? update.progress
                  : null,
            ),
          ),
        ),
      ];
    }
    if (update.updateAvailable && release != null) {
      final String? error = update.error;
      final List<String> changes = release.changes;
      final String summary =
          error ??
          (changes.isEmpty
              ? 'Install the latest version now.'
              : changes.length == 1
              ? changes.first
              : '${changes.first}  (+${changes.length - 1} more)');
      return <Widget>[
        PlayRow(
          icon: PlayIcons.download,
          label: 'Update available — ${release.versionName}',
          subtitle: summary,
          showChevron: false,
          trailing: PlayButton(
            label: 'Update',
            size: PlayButtonSize.sm,
            onPressed: () => unawaited(
              ref.read(updateControllerProvider.notifier).install(),
            ),
          ),
        ),
      ];
    }
    if (update.status == UpdateStatus.error) {
      return <Widget>[
        PlayRow(
          icon: PlayIcons.error,
          label: 'Could not check for updates',
          subtitle: update.error ?? 'Try again later.',
          showChevron: false,
          trailing: PlayButton(
            label: 'Retry',
            variant: PlayButtonVariant.ghost,
            size: PlayButtonSize.sm,
            onPressed: () =>
                unawaited(ref.read(updateControllerProvider.notifier).check()),
          ),
        ),
      ];
    }
    if (update.status == UpdateStatus.checking) {
      return const <Widget>[
        PlayRow(
          icon: PlayIcons.loading,
          label: 'Checking for updates…',
          showChevron: false,
          trailing: PlaySpinner(size: 22, strokeWidth: 2),
        ),
      ];
    }
    if (update.status == UpdateStatus.upToDate) {
      return const <Widget>[
        PlayRow(
          icon: PlayIcons.check,
          label: 'You are up to date',
          showChevron: false,
        ),
      ];
    }
    return <Widget>[
      PlayRow(
        icon: PlayIcons.refresh,
        label: 'Check for updates',
        showChevron: false,
        onTap: () =>
            unawaited(ref.read(updateControllerProvider.notifier).check()),
      ),
    ];
  }
}

/// A section heading.
class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PlaySpace.xs,
        PlaySpace.xl,
        PlaySpace.xs,
        PlaySpace.sm,
      ),
      child: Text(
        text.toUpperCase(),
        style: PlayType.overline.copyWith(
          color: PlayColors.of(context).inkMuted,
        ),
      ),
    );
  }
}

/// The About sheet, shown from settings.
class _AboutSheet extends StatelessWidget {
  const _AboutSheet({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PlaySpace.lg,
        0,
        PlaySpace.lg,
        PlaySpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'OpenMaps',
            style: PlayType.headline.copyWith(color: colors.ink),
          ),
          const SizedBox(height: PlaySpace.xs),
          Text(
            'Version $version',
            style: PlayType.caption.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: PlaySpace.lg),
          Text(
            'Map data © Mapbox and OpenStreetMap contributors (ODbL). Search by '
            'Mapbox or OpenStreetMap (Photon + Overpass). Routing by Valhalla and '
            'public transport by Transitous (transitous.org/sources) or the '
            'Camelus map services.',
            style: PlayType.body.copyWith(color: colors.ink),
          ),
          const SizedBox(height: PlaySpace.md),
          Text(
            'Camelus Maps, open map data with social features, built for '
            'exploring.',
            style: PlayType.body.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// A short description of the current push state for the settings row.
String _pushStatusText(PushStatus status) {
  if (!status.serverConfigured) {
    return 'No push backend configured in this build';
  }
  if (!status.supported) {
    return 'Not supported on this platform';
  }
  if (status.transport == PushTransport.off) {
    return 'Off';
  }
  if (status.registered) {
    return 'Registered over Firebase';
  }
  // Prefer the concrete reason the bootstrap recorded (sign out, no token,
  // server refusal), so a failure is never hidden behind a generic line.
  final String? error = status.error;
  if (error != null && error.isNotEmpty) {
    return error;
  }
  if (!status.permissionGranted) {
    return 'Notifications are not allowed in system settings';
  }
  if (status.hasToken) {
    return 'Registered, waiting for the server (Firebase)';
  }
  return 'Not registered yet';
}
