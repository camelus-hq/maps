import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

/// The active [AppConfig]. Overridden in `lib/app/di.dart` with the instance
/// parsed at bootstrap so tests can inject their own.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => AppConfig.fromEnvironment(),
);
