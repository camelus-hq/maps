# openmaps_notifications

OpenMaps' own local-notification channel.

This is a Flutter **plugin** rather than a `MethodChannel` registered in the app's
`MainActivity` for one specific reason: a data-only FCM push runs its Dart
handler in a **separate Flutter engine**, and only pubspec plugins are registered
on that engine. The wake-up isolate is the only place a gift wrap can be
decrypted, so it is also the only place that knows what the notification should
say — and it needs this channel to exist there too.

```dart
import 'package:openmaps_notifications/openmaps_notifications.dart';

await OpenMapsNotifications.show(
  id: 1,
  title: 'Mira',
  body: 'is sharing their location with you',
  payload: '{"route":"/friends"}',
);
```

Every call is guarded: an unavailable platform or a native failure is a no-op, so
a failure to notify can never take down a background isolate.

* **Android** posts through `NotificationCompat` on a `openmaps_push` channel.
* **iOS** schedules a `UNUserNotificationCenter` request with a `nil` trigger.

The small icon is a system drawable: a plugin cannot use the host app's
resources.
