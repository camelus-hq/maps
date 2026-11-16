import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ndk_flutter/l10n/app_localizations.dart' as ndk_l10n;

import '../core/theme/app_theme.dart';
import '../core/theme/play/play_colors.dart';
import '../core/theme/play/play_tokens.dart';
import '../domain/entities/app_settings.dart';
import '../features/feedback/widgets/alpha_banner.dart';
import '../features/update/widgets/update_prompt.dart';
import '../state/screenshot.dart';
import '../state/settings.dart';
import 'router.dart';

/// The root widget: themes plus the app-level router, wrapped in the repaint
/// boundary the control channel captures for `ui.screenshot`.
class OpenMapsApp extends StatefulWidget {
  const OpenMapsApp({super.key});

  @override
  State<OpenMapsApp> createState() => _OpenMapsAppState();
}

class _OpenMapsAppState extends State<OpenMapsApp> {
  late final GoRouter _router = buildAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: rootScreenshotKey,
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          final AppThemeMode theme = ref.watch(settingsProvider).theme;
          return MaterialApp.router(
            title: 'OpenMaps',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: switch (theme) {
              AppThemeMode.light => ThemeMode.light,
              AppThemeMode.dark => ThemeMode.dark,
              AppThemeMode.system => ThemeMode.system,
            },
            // The ndk_flutter widgets (Nostr login) need their strings.
            localizationsDelegates:
                ndk_l10n.AppLocalizations.localizationsDelegates,
            supportedLocales: ndk_l10n.AppLocalizations.supportedLocales,
            routerConfig: _router,
            builder: (BuildContext context, Widget? child) {
              // Resolve the Play palette from the theme the app actually
              // selected (System/Light/Dark), so the Play UI follows the
              // settings toggle and the platform, not just the platform.
              final Brightness brightness = Theme.of(context).brightness;
              final PlayColors colors = brightness == Brightness.dark
                  ? PlayColors.dark
                  : PlayColors.light;
              return PlayTheme(
                colors: colors,
                child: DefaultTextStyle(
                  style: PlayType.body.copyWith(color: colors.ink),
                  child: AlphaBannerHost(
                    child: UpdatePromptHost(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
