import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'push_config.dart';
import 'push_sender.dart';

/// Firebase Messaging credentials: the project id plus an OAuth2 client whose
/// access token is refreshed automatically.
class FcmAuth {
  const FcmAuth({required this.projectId, required this.client});

  final String projectId;
  final AutoRefreshingAuthClient client;
}

typedef FcmAuthLoader = Future<FcmAuth> Function();

/// Sends a **Firebase Cloud Messaging** HTTP v1 message.
///
/// Only the Messaging scope is requested and only `messages:send` is called, so
/// no other Google API is reachable with these credentials — "keep the Google
/// libraries minimal" applies on the server too. The message is **data-only**
/// with the gift wrap under `encryptedEvent`; the device decrypts it in a
/// background isolate and posts its own local notification. FCM/APNs therefore
/// never see the message text.
class FcmSender implements PushSender {
  FcmSender({this.authLoader, this.projectIdOverride});

  /// Loads credentials; defaults to [defaultFcmAuthLoader].
  final FcmAuthLoader? authLoader;

  /// Overrides the project id from the credentials (tests).
  final String? projectIdOverride;

  FcmAuth? _auth;

  @override
  String get transport => 'firebase';

  @override
  Future<PushSendResult> send(String token, String encryptedEventJson) async {
    final FcmAuth? auth = await _resolveAuth();
    if (auth == null) {
      return const PushSendResult.failure(
        error: 'Firebase credentials are not configured',
      );
    }

    final Uri uri = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/${auth.projectId}/messages:send',
    );
    final Map<String, Object?> message = <String, Object?>{
      'message': <String, Object?>{
        'token': token,
        'data': <String, String>{'encryptedEvent': encryptedEventJson},
        // Deliver immediately; the app decrypts in the background isolate.
        'android': <String, Object?>{'priority': 'high'},
        // iOS: a background (content-available) data message, so the app can
        // wake, decrypt and raise its own local notification.
        'apns': <String, Object?>{
          'headers': <String, String>{
            'apns-push-type': 'background',
            'apns-priority': '5',
          },
          'payload': <String, Object?>{
            'aps': <String, Object?>{'content-available': 1},
          },
        },
      },
    };

    try {
      final http.Response response = await auth.client
          .post(
            uri,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
            body: jsonEncode(message),
          )
          .timeout(PushConfig.sendTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const PushSendResult.success();
      }
      return failureFromBody(response.body, response.statusCode);
    } on TimeoutException {
      return const PushSendResult.failure(error: 'FCM send timed out');
    } catch (error) {
      return PushSendResult.failure(error: 'FCM send failed: $error');
    }
  }

  Future<FcmAuth?> _resolveAuth() async {
    if (_auth != null) {
      return _auth;
    }
    try {
      final FcmAuthLoader loader = authLoader ?? defaultFcmAuthLoader;
      final FcmAuth auth = await loader();
      _auth = FcmAuth(
        projectId: projectIdOverride ?? auth.projectId,
        client: auth.client,
      );
      return _auth;
    } catch (error) {
      return null;
    }
  }

  /// Maps an FCM error body to a [PushSendResult]; true when the failure means
  /// the token is dead and must be deleted. Exposed for tests.
  static PushSendResult failureFromBody(String body, int statusCode) {
    final Map<String, dynamic>? decoded = tryDecodeObject(body);
    final Object? error = decoded?['error'];
    if (error is Map<String, dynamic>) {
      final Object? details = error['details'];
      if (details is List) {
        for (final Object? detail in details) {
          if (detail is Map<String, dynamic>) {
            final Object? code = detail['errorCode'];
            if (code == 'UNREGISTERED' || code == 'INVALID_ARGUMENT') {
              return const PushSendResult.failure(
                invalidToken: true,
                error: 'token no longer registered',
              );
            }
          }
        }
      }
      final Object? message = error['message'];
      if (message is String &&
          message.toLowerCase().contains('registration token')) {
        return PushSendResult.failure(
          invalidToken: true,
          error: message,
        );
      }
    }
    return PushSendResult.failure(error: 'HTTP $statusCode');
  }
}

/// Loads Firebase credentials from the environment, in order:
///
/// 1. `FIREBASE_SERVICE_ACCOUNT_JSON` — the service-account file contents.
/// 2. `FIREBASE_SERVICE_ACCOUNT_FILE` — a path to that file.
/// 3. `config/firebase_service_account_key.json` (gitignored) — the default
///    location for local development.
/// 4. Application Default Credentials (e.g. `GOOGLE_APPLICATION_CREDENTIALS`).
///
/// The project id comes from the credentials, or `FIREBASE_PROJECT_ID`.
Future<FcmAuth> defaultFcmAuthLoader() async {
  const List<String> scopes = <String>[
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  final String? inline = Platform.environment['FIREBASE_SERVICE_ACCOUNT_JSON'];
  if (inline != null && inline.trim().isNotEmpty) {
    final ServiceAccountCredentials credentials =
        ServiceAccountCredentials.fromJson(inline);
    return FcmAuth(
      projectId: _projectId(credentials),
      client: await clientViaServiceAccount(credentials, scopes),
    );
  }

  final File? file = _findServiceAccountFile();
  if (file != null) {
    final ServiceAccountCredentials credentials =
        ServiceAccountCredentials.fromJson(await file.readAsString());
    return FcmAuth(
      projectId: _projectId(credentials),
      client: await clientViaServiceAccount(credentials, scopes),
    );
  }

  final AutoRefreshingAuthClient client =
      await clientViaApplicationDefaultCredentials(scopes: scopes);
  final String? projectId = Platform.environment['FIREBASE_PROJECT_ID'];
  if (projectId == null || projectId.isEmpty) {
    throw StateError(
      'No FIREBASE_PROJECT_ID and no service-account file to read it from',
    );
  }
  return FcmAuth(projectId: projectId, client: client);
}

/// Finds the service-account JSON: `FIREBASE_SERVICE_ACCOUNT_FILE`, then
/// `config/firebase_service_account_key.json`, then any
/// `*firebase-adminsdk*.json` under `config/` or `../config/`.
File? _findServiceAccountFile() {
  final String? explicit = Platform.environment['FIREBASE_SERVICE_ACCOUNT_FILE']
      ?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    final File file = File(explicit);
    return file.existsSync() ? file : null;
  }

  final List<String> candidates = <String>[
    'config/firebase_service_account_key.json',
  ];
  for (final String directory in <String>['config', '../config']) {
    try {
      final Directory dir = Directory(directory);
      if (!dir.existsSync()) {
        continue;
      }
      for (final FileSystemEntity entity in dir.listSync()) {
        if (entity is File && entity.path.contains('firebase-adminsdk')) {
          candidates.add(entity.path);
        }
      }
    } catch (_) {
      // A missing/unreadable directory is not fatal; try the next candidate.
    }
  }
  for (final String path in candidates) {
    final File file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }
  return null;
}

String _projectId(ServiceAccountCredentials credentials) {
  final String? projectId = credentials.projectId;
  if (projectId == null || projectId.isEmpty) {
    throw StateError('Service account JSON has no project_id');
  }
  return projectId;
}
