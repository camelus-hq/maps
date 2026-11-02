import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/ports.dart';
import '../../../state/settings.dart';

/// First-run onboarding: a short location rationale shown once, then the map.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(Icons.explore, size: 72, color: scheme.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Welcome to OpenMaps',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'See your area on the map, search for places and get '
                'turn-by-turn directions.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your location stays on your device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => unawaited(_finish(ref, requestLocation: true)),
                child: const Text('Allow location & continue'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () =>
                    unawaited(_finish(ref, requestLocation: false)),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finish(WidgetRef ref, {required bool requestLocation}) async {
    await ref.read(setOnboardingSeenProvider)(true);
    if (requestLocation) {
      // Prompts for permission; the service degrades to "no fix" if refused.
      unawaited(ref.read(locationServiceProvider).lastKnown());
    }
  }
}
