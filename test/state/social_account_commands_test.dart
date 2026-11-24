import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/user_profile.dart';
import 'package:openmaps/domain/entities/user_relay_lists.dart';
import 'package:openmaps/state/commands/command.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/social.dart';

void main() {
  late FakeSocialService social;
  late ProviderContainer container;

  setUp(() {
    social = FakeSocialService();
    container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
  });

  tearDown(() => container.dispose());

  Future<Object?> dispatch(
    String id, [
    Map<String, Object?> params = const {},
  ]) => container.read(commandRegistryProvider).dispatch(id, params);

  test('social.signup creates an identity without leaking the key', () async {
    final Map<String, Object?> result =
        await dispatch('social.signup') as Map<String, Object?>;

    expect(social.createAccountCalls, 1);
    expect(result['signedIn'], isTrue);
    expect(result['pubkey'], FakeSocialService.demoUserPubkey);
    // The private key is never part of a command result.
    expect(result.containsKey('nsec'), isFalse);
  });

  test('social.signin.bunker validates and connects', () async {
    await expectLater(
      dispatch('social.signin.bunker', <String, Object?>{'bunker': 'nope'}),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      dispatch('social.signin.bunker'),
      throwsA(isA<CommandException>()),
    );

    const String url = 'bunker://abc?relay=wss://relay.example';
    final Map<String, Object?> result = await dispatch(
      'social.signin.bunker',
      <String, Object?>{'bunker': url},
    ) as Map<String, Object?>;

    expect(social.signedInWithBunker, url);
    expect(result['signedIn'], isTrue);
  });

  test('social.signin.signer signs in with the signer app', () async {
    final Map<String, Object?> result =
        await dispatch('social.signin.signer') as Map<String, Object?>;
    expect(social.signedInWithSignerApp, isTrue);
    expect(result['signedIn'], isTrue);

    social.supportsSignerApp = false;
    await expectLater(
      dispatch('social.signin.signer'),
      throwsA(isA<ValidationException>()),
    );
  });

  test('social.profile.get and social.profile.save round-trip', () async {
    social.profile = const UserProfile(name: 'Ada', about: 'Pioneer');

    Map<String, Object?> got =
        await dispatch('social.profile.get') as Map<String, Object?>;
    expect(got['name'], 'Ada');
    expect(got['about'], 'Pioneer');

    got = await dispatch('social.profile.save', <String, Object?>{
      'name': 'Grace',
      'about': 'Compiler',
      'picture': 'https://example.test/p.png',
    }) as Map<String, Object?>;

    expect(got['name'], 'Grace');
    expect(social.profile.name, 'Grace');
    expect(social.profile.about, 'Compiler');
    expect(social.profile.pictureUrl, 'https://example.test/p.png');

    // An omitted picture clears it.
    await dispatch('social.profile.save', <String, Object?>{'name': 'Grace'});
    expect(social.profile.pictureUrl, isNull);
  });

  test('social.relays.get and social.relays.save round-trip', () async {
    social.relays = const UserRelays(
      nip65: <RelayEntry>[
        RelayEntry(url: 'wss://a', marker: RelayMarker.inbox),
      ],
      dm: <String>['wss://b'],
    );

    Map<String, Object?> got =
        await dispatch('social.relays.get') as Map<String, Object?>;
    final List<Object?> listed = got['nip65']! as List<Object?>;
    final Map<String, Object?> first = listed.first! as Map<String, Object?>;
    expect(first['url'], 'wss://a');
    expect(first['marker'], 'inbox');
    expect(first['read'], isTrue);
    expect(first['write'], isFalse);
    expect(got['dm'], <String>['wss://b']);
    expect(got['complete'], isTrue);

    got = await dispatch('social.relays.save', <String, Object?>{
      'nip65': <Object?>[
        <String, Object?>{'url': 'wss://c', 'marker': 'outbox'},
        'wss://e',
      ],
      'dm': <Object?>['wss://d'],
    }) as Map<String, Object?>;
    expect(got['complete'], isTrue);
    expect(social.relays.nip65, <RelayEntry>[
      const RelayEntry(url: 'wss://c', marker: RelayMarker.outbox),
      const RelayEntry(url: 'wss://e'),
    ]);
    expect(social.relays.dm, <String>['wss://d']);

    await expectLater(
      dispatch('social.relays.save', <String, Object?>{
        'nip65': <Object?>[],
        'dm': <Object?>['wss://d'],
      }),
      throwsA(isA<ValidationException>()),
    );
  });

  test('social.relays.ensureDefaults fills empty lists only', () async {
    final Map<String, Object?> filled =
        await dispatch('social.relays.ensureDefaults') as Map<String, Object?>;
    final List<Object?> listed = filled['nip65']! as List<Object?>;
    expect((listed.first! as Map<String, Object?>)['url'], defaultNostrRelay);
    expect(filled['dm'], <String>[defaultNostrRelay]);
    expect(social.relays.nip65.first.url, defaultNostrRelay);

    social.relays = const UserRelays(
      nip65: <RelayEntry>[RelayEntry(url: 'wss://mine')],
      dm: <String>[],
    );
    container.invalidate(relaysControllerProvider);
    final Map<String, Object?> next =
        await dispatch('social.relays.ensureDefaults') as Map<String, Object?>;
    expect(
      ((next['nip65']! as List<Object?>).first! as Map<String, Object?>)['url'],
      'wss://mine',
    );
    expect(next['dm'], <String>[defaultNostrRelay]);
  });
}
