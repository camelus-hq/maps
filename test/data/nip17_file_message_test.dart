import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip01/key_pair.dart';

/// Exercises the real NIP-17 encrypted-file crypto the feedback adapter relies
/// on, in-process (two identities, no relays): a screenshot is encrypted, tagged
/// exactly as Amethyst expects, gift-wrapped to the recipient, unwrapped and
/// decrypted.
void main() {
  Ndk buildNdk() => Ndk(
    NdkConfig(
      cache: MemCacheManager(),
      eventVerifier: Bip340EventVerifier(),
      bootstrapRelays: const <String>[],
    ),
  );

  void signIn(Ndk ndk, KeyPair pair) {
    final String? privkey = pair.privateKey;
    expect(privkey, isNotNull);
    ndk.accounts.loginPrivateKey(pubkey: pair.publicKey, privkey: privkey!);
  }

  test('an encrypted screenshot survives a gift wrap intact', () async {
    final KeyPair sender = Bip340.generatePrivateKey();
    final KeyPair friend = Bip340.generatePrivateKey();
    final Ndk senderNdk = buildNdk();
    final Ndk friendNdk = buildNdk();
    addTearDown(senderNdk.destroy);
    addTearDown(friendNdk.destroy);
    signIn(senderNdk, sender);
    signIn(friendNdk, friend);

    final Uint8List png = Uint8List.fromList(
      List<int>.generate(512, (int i) => i % 256),
    );
    final Nip17EncryptedFile encrypted = await Nip17FileCrypto.encrypt(png);
    final Nip17FileMetadata metadata = Nip17FileMetadata.fromEncryptedFile(
      url: Uri.parse('https://files.example/report.png.enc'),
      mimeType: 'image/png',
      encryptedFile: encrypted,
    );

    final Nip01Event rumor = await senderNdk.giftWrap.createRumor(
      customPubkey: sender.publicKey,
      kind: 15,
      content: metadata.url.toString(),
      tags: <List<String>>[
        <String>['p', friend.publicKey],
        ...metadata.toTags(),
      ],
    );
    final Nip01Event wrap = await senderNdk.giftWrap.toGiftWrap(
      rumor: rumor,
      recipientPubkey: friend.publicKey,
    );

    final Nip01Event unwrapped = await friendNdk.giftWrap.fromGiftWrap(
      giftWrap: wrap,
    );
    expect(unwrapped.kind, 15);

    final Nip17FileMetadata? parsed = Nip17FileMetadata.tryParse(unwrapped);
    expect(parsed, isNotNull);
    expect(parsed!.mimeType, 'image/png');
    expect(parsed.encryptionAlgorithm, 'aes-gcm');
    expect(parsed.url.toString(), metadata.url.toString());
    expect(parsed.encryptedSha256, encrypted.encryptedSha256);
    expect(parsed.originalSha256, encrypted.originalSha256);

    final Uint8List decrypted = await Nip17FileCrypto.decrypt(
      ciphertext: encrypted.ciphertext,
      metadata: parsed,
    );
    expect(decrypted, png);
  });

  test('a tampered ciphertext fails the hash check', () async {
    final Uint8List png = Uint8List.fromList(
      List<int>.generate(64, (int i) => i),
    );
    final Nip17EncryptedFile encrypted = await Nip17FileCrypto.encrypt(png);
    final Nip17FileMetadata metadata = Nip17FileMetadata.fromEncryptedFile(
      url: Uri.parse('https://files.example/report.png.enc'),
      mimeType: 'image/png',
      encryptedFile: encrypted,
    );
    final Uint8List tampered = Uint8List.fromList(encrypted.ciphertext);
    tampered[0] = tampered[0] ^ 0xff;

    await expectLater(
      Nip17FileCrypto.decrypt(ciphertext: tampered, metadata: metadata),
      throwsA(isA<FormatException>()),
    );
  });
}
