import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/user_profile.dart';
import 'package:openmaps/domain/entities/user_relay_lists.dart';

void main() {
  group('UserProfile', () {
    test('trims and caps the text fields', () {
      final UserProfile profile = UserProfile(
        name: '  ${'n' * 200}  ',
        about: '  ${'a' * 900}  ',
      );
      expect(profile.safeName.length, UserProfile.maxNameLength);
      expect(profile.safeAbout.length, UserProfile.maxAboutLength);
    });

    test('isEmpty tracks whether there is anything to publish', () {
      expect(const UserProfile().isEmpty, isTrue);
      expect(const UserProfile(name: 'x').isEmpty, isFalse);
      expect(const UserProfile(pictureUrl: 'https://x').isEmpty, isFalse);
    });

    test('copyWith can clear the picture', () {
      const UserProfile profile = UserProfile(
        name: 'Ada',
        pictureUrl: 'https://x',
      );
      expect(profile.copyWith(name: 'Grace').pictureUrl, 'https://x');
      expect(profile.copyWith(clearPicture: true).pictureUrl, isNull);
    });
  });

  group('UserRelays', () {
    test('isComplete requires both lists', () {
      expect(const UserRelays().isComplete, isFalse);
      expect(
        const UserRelays(nip65: <RelayEntry>[RelayEntry(url: 'wss://a')])
            .isComplete,
        isFalse,
      );
      expect(
        const UserRelays(
          nip65: <RelayEntry>[RelayEntry(url: 'wss://a')],
          dm: <String>['wss://b'],
        ).isComplete,
        isTrue,
      );
    });

    test('RelayMarker maps inbox/outbox to read/write', () {
      expect(RelayMarker.both.reads, isTrue);
      expect(RelayMarker.both.writes, isTrue);
      expect(RelayMarker.inbox.reads, isTrue);
      expect(RelayMarker.inbox.writes, isFalse);
      expect(RelayMarker.outbox.reads, isFalse);
      expect(RelayMarker.outbox.writes, isTrue);
    });

    test('equality compares contents', () {
      const UserRelays a = UserRelays(
        nip65: <RelayEntry>[RelayEntry(url: 'wss://a')],
        dm: <String>['wss://b'],
      );
      const UserRelays b = UserRelays(
        nip65: <RelayEntry>[RelayEntry(url: 'wss://a')],
        dm: <String>['wss://b'],
      );
      const UserRelays c = UserRelays(
        nip65: <RelayEntry>[
          RelayEntry(url: 'wss://a', marker: RelayMarker.inbox),
        ],
        dm: <String>['wss://b'],
      );
      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
