// Copyright (C) 2026 1-leo

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk_flutter/ndk_flutter.dart';

import 'app/app.dart';
import 'app/database_bootstrap.dart';
import 'app/di.dart';
import 'control/control_args.dart';
import 'control/control_server.dart';
import 'core/config/app_config.dart';
import 'data/nostr/nostr_bootstrap.dart';
import 'domain/ports/app_database.dart';
import 'state/commands/commands_provider.dart';
import 'state/ports.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppConfig config = AppConfig.fromEnvironment();

  // One Nostr client for the whole app; accounts are restored from secure
  // storage before the first frame so a signed-in user starts signed in.
  final Ndk ndk = NostrBootstrap.createClient();
  final NdkFlutter ndkFlutter = NostrBootstrap.wrap(ndk);
  try {
    await ndkFlutter.restoreAccountsState();
  } catch (error) {
    debugPrint('Could not restore the Nostr session: $error');
  }

  // The local database (metrics + most settings). Opened before the first frame
  // so its migrations run once at startup; a failure falls back to an in-memory
  // store rather than blocking the app.
  final AppDatabase database = await openAppDatabaseSafely();

  final ProviderContainer container = ProviderContainer(
    overrides: buildAppOverrides(
      config,
      ndk: ndk,
      ndkFlutter: ndkFlutter,
      database: database,
    ),
  );

  // Development key from `--dart-define=NOSTR_NSEC=…` (never committed): sign
  // in without the login screen. A restored account always wins, and the key is
  // ignored (and compiled out, see AppConfig.fromEnvironment) in a release
  // build so a production APK never auto-signs-in.
  if (!kReleaseMode &&
      config.hasNostrKey &&
      !container.read(socialServiceProvider).isLoggedIn) {
    try {
      await container
          .read(socialServiceProvider)
          .signInWithPrivateKey(config.nostrNsec);
    } catch (error) {
      debugPrint('Could not sign in with the configured Nostr key: $error');
    }
  }

  // The control channel is debug/profile only and localhost-bound; it must
  // never exist in a release build (AGENTS.md §Driving the app).
  final int? controlPort = ControlArgs.parse(args).port;
  if (controlPort != null && !kReleaseMode) {
    final ControlServer server = ControlServer(
      registry: container.read(commandRegistryProvider),
      port: controlPort,
    );
    unawaited(
      server.start().catchError((Object error) {
        debugPrint(
          'Control channel failed to start on port $controlPort: $error',
        );
      }),
    );
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const OpenMapsApp()),
  );
}
