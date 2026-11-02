import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ndk_flutter/ndk_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/app_update.dart';
import '../../../domain/entities/friend.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/config.dart';
import '../../../state/ports.dart';
import '../../../state/settings.dart';
import '../../../state/social.dart';
import '../../../state/update.dart';
import '../../social/widgets/friend_avatar.dart';

/// Functional settings: distance units, theme, search provider, about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final AppConfig config = ref.watch(appConfigProvider);
    final bool hasMapboxToken = config.hasMapboxToken;
    final bool hasCamelusToken = config.hasCamelusToken;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('Account'),
          const _AccountTile(),
          const Divider(height: AppSpacing.xl),
          const _SectionHeader('Distance units'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SegmentedButton<DistanceUnit>(
              segments: const <ButtonSegment<DistanceUnit>>[
                ButtonSegment<DistanceUnit>(
                  value: DistanceUnit.metric,
                  label: Text('Metric'),
                ),
                ButtonSegment<DistanceUnit>(
                  value: DistanceUnit.imperial,
                  label: Text('Imperial'),
                ),
              ],
              selected: <DistanceUnit>{settings.unit},
              onSelectionChanged: (Set<DistanceUnit> selection) => unawaited(
                ref.read(settingsProvider.notifier).setUnit(selection.first),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader('Theme'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SegmentedButton<AppThemeMode>(
              segments: const <ButtonSegment<AppThemeMode>>[
                ButtonSegment<AppThemeMode>(
                  value: AppThemeMode.system,
                  label: Text('System'),
                ),
                ButtonSegment<AppThemeMode>(
                  value: AppThemeMode.light,
                  label: Text('Light'),
                ),
                ButtonSegment<AppThemeMode>(
                  value: AppThemeMode.dark,
                  label: Text('Dark'),
                ),
              ],
              selected: <AppThemeMode>{settings.theme},
              onSelectionChanged: (Set<AppThemeMode> selection) => unawaited(
                ref.read(settingsProvider.notifier).setTheme(selection.first),
              ),
            ),
          ),
          const Divider(height: AppSpacing.xl),
          const _SectionHeader('Search provider'),
          RadioGroup<SearchBackend>(
            groupValue: settings.searchBackend,
            onChanged: (SearchBackend? value) {
              if (value != null) {
                unawaited(
                  ref.read(settingsProvider.notifier).setSearchBackend(value),
                );
              }
            },
            child: Column(
              children: <Widget>[
                RadioListTile<SearchBackend>(
                  value: SearchBackend.mapbox,
                  title: const Text('Mapbox'),
                  subtitle: Text(
                    hasMapboxToken
                        ? 'Mapbox Geocoding and Search Box'
                        : 'Needs an access token — OpenStreetMap is used '
                              'instead',
                  ),
                ),
                const RadioListTile<SearchBackend>(
                  value: SearchBackend.openstreetmap,
                  title: Text('OpenStreetMap'),
                  subtitle: Text(
                    'Photon search and Overpass places (no account)',
                  ),
                ),
                RadioListTile<SearchBackend>(
                  value: SearchBackend.camelus,
                  title: const Text('Camelus'),
                  subtitle: Text(
                    hasCamelusToken
                        ? 'Photon, Overpass, Nominatim, Valhalla and transit '
                              'via camelus.app'
                        : 'Needs an API key — OpenStreetMap is used instead',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: AppSpacing.xl),
          const _SectionHeader('Developer'),
          SwitchListTile(
            secondary: const Icon(Icons.data_object),
            title: const Text('Show all OpenStreetMap tags'),
            subtitle: const Text(
              'List every raw OSM tag on the place details sheet',
            ),
            value: settings.showOsmTags,
            onChanged: (bool value) => unawaited(
              ref.read(settingsProvider.notifier).setShowOsmTags(value),
            ),
          ),
          const Divider(height: AppSpacing.xl),
          const _SectionHeader('App update'),
          const _AppUpdateTile(),
          const Divider(height: AppSpacing.xl),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Clear recent searches'),
            onTap: () async {
              await ref.read(placesRepositoryProvider).clearRecentQueries();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recent searches cleared')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About OpenMaps'),
            onTap: () => _showAbout(context, ref),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('Offline'),
            subtitle: Text('Searches and directions need a connection'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context, WidgetRef ref) {
    final AppVersion version =
        ref.read(installedVersionProvider).value ?? AppVersion.unknown;
    showAboutDialog(
      context: context,
      applicationName: 'OpenMaps',
      applicationVersion: version.isKnown ? version.versionName : '0.1.0',
      applicationLegalese:
          'Map data © Mapbox and OpenStreetMap contributors (ODbL). Search by '
          'Mapbox or OpenStreetMap (Photon + Overpass). Routing by Valhalla and '
          'public transport by Transitous (transitous.org/sources) or the '
          'Camelus map services.',
      children: const <Widget>[
        SizedBox(height: AppSpacing.sm),
        Text(
          'Camelus Maps, open map data with social features, built for exploring.',
        ),
      ],
    );
  }
}

/// The Nostr account: who is signed in (profile picture + name) and a way out.
///
/// Signing in happens on `/profile`; this tile shows the current identity and
/// dispatches the same `social.logout` command as the profile screen, so the
/// behaviour is identical and drivable by agents.
class _AccountTile extends ConsumerWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? pubkey = ref.watch(nostrPubkeyProvider).value;
    if (pubkey == null) {
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: const Text('Not signed in'),
        subtitle: const Text('Sign in to share your live location'),
        trailing: const Icon(Icons.chevron_right),
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
        ListTile(
          leading: FriendAvatar(
            label: name,
            pictureUrl: profile?.pictureUrl,
            size: 40,
          ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(npub, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => unawaited(_signOut(context, ref)),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Signed out')));
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
        ListTile(
          leading: const Icon(Icons.smartphone_outlined),
          title: const Text('Installed version'),
          subtitle: Text(label),
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
        ListTile(
          leading: const Icon(Icons.downloading_outlined),
          title: const Text('Installing the update…'),
          subtitle: LinearProgressIndicator(
            value: update.progress > 0 && update.progress < 1
                ? update.progress
                : null,
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
        ListTile(
          leading: const Icon(Icons.system_update_alt),
          title: Text('Update available — ${release.versionName}'),
          subtitle: Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: error == null
                ? null
                : TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          trailing: FilledButton(
            onPressed: () => unawaited(
              ref.read(updateControllerProvider.notifier).install(),
            ),
            child: const Text('Update'),
          ),
        ),
      ];
    }
    if (update.status == UpdateStatus.error) {
      return <Widget>[
        ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Could not check for updates'),
          subtitle: Text(update.error ?? 'Try again later.'),
          trailing: TextButton(
            onPressed: () =>
                unawaited(ref.read(updateControllerProvider.notifier).check()),
            child: const Text('Retry'),
          ),
        ),
      ];
    }
    if (update.status == UpdateStatus.checking) {
      return const <Widget>[
        ListTile(
          leading: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Checking for updates…'),
        ),
      ];
    }
    if (update.status == UpdateStatus.upToDate) {
      return const <Widget>[
        ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('You are up to date'),
        ),
      ];
    }
    return <Widget>[
      ListTile(
        leading: const Icon(Icons.refresh),
        title: const Text('Check for updates'),
        onTap: () =>
            unawaited(ref.read(updateControllerProvider.notifier).check()),
      ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

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
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
