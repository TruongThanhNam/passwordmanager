import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/crypto/random_source.dart';
import 'package:pak_manager/core/format/vault_file_codec.dart';
import 'package:pak_manager/core/model/recent_entry.dart';
import 'package:pak_manager/core/model/vault_card.dart';
import 'package:sodium/sodium_sumo.dart';

import '../vault_fixture.dart';

void main() {
  late SodiumSumo sodium;
  late VaultFileCodec codec;

  setUpAll(() async {
    sodium = await initSodium();
    codec = VaultFileCodec(sodium, SodiumRandomSource(sodium));
  });
  late SecureKey dek;

  setUp(() => dek = sodium.secureCopy(fixtureDek()));
  tearDown(() => dek.dispose());

  Uint8List open(Uint8List file, String kind) =>
      sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
        cipherText: file.sublist(24),
        nonce: file.sublist(0, 24),
        key: dek,
        additionalData: ascii.encode('PAK-VAULT/$kind/v1'),
      );

  /// Mã hóa [plaintext] tùy ý như một file `kind` hợp lệ về mặt AEAD.
  Uint8List seal(String plaintext, String kind) {
    final nonce = sodium.randombytes.buf(24);
    final ct = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: utf8.encode(plaintext),
      nonce: nonce,
      key: dek,
      additionalData: ascii.encode('PAK-VAULT/$kind/v1'),
    );
    return Uint8List.fromList([...nonce, ...ct]);
  }

  Map<String, Object?> cardJson() => <String, Object?>{
    'id': '3f2b8c1e-5d4a-4e6f-9a7b-1c2d3e4f5a6b',
    'title': 'Example Mail',
    'username': 'alice@example.com',
    'password': 'Fake-Pass-0001!',
    'note': '',
    'createdAt': 1762300800000,
  };

  Map<String, Object?> recentJson() => <String, Object?>{
    'password': 'K9#mVq2!xLp7wZr',
    'recordedAt': 1762390800000,
  };

  VaultFileResult<List<VaultCard>> decodeCardsJson(Object? json) =>
      codec.decodeCards(seal(jsonEncode(json), 'cards'), dek);

  VaultFileResult<List<RecentEntry>> decodeRecentJson(Object? json) =>
      codec.decodeRecent(seal(jsonEncode(json), 'recent'), dek);

  group('golden', () {
    test('ad20_encode_cards_matches_fixture_byte_for_byte', () {
      final random = QueueRandomSource([fixtureCardsNonce()]);

      final out = VaultFileCodec(sodium, random).encodeCards(fixtureCards, dek);

      expect(out, vaultFixture('cards'));
      expect(random.requested, [24]);
    });

    test('ad20_encode_recent_matches_fixture_byte_for_byte', () {
      final random = QueueRandomSource([fixtureRecentNonce()]);

      final out = VaultFileCodec(
        sodium,
        random,
      ).encodeRecent(fixtureRecent, dek);

      expect(out, vaultFixture('recent'));
    });

    test('ad20_decode_fixture_cards_and_recent', () {
      final cards = codec.decodeCards(vaultFixture('cards'), dek);
      final recent = codec.decodeRecent(vaultFixture('recent'), dek);

      expect((cards as VaultFileOk).value, fixtureCards);
      expect((recent as VaultFileOk).value, fixtureRecent);
    });
  });

  group('encode', () {
    test('ad16_encode_twice_uses_fresh_nonce_and_round_trips', () {
      final a = codec.encodeCards(fixtureCards, dek)!;
      final b = codec.encodeCards(fixtureCards, dek)!;

      expect(a.sublist(0, 24), isNot(b.sublist(0, 24)));
      expect(a, isNot(b));
      expect((codec.decodeCards(a, dek) as VaultFileOk).value, fixtureCards);
      expect((codec.decodeCards(b, dek) as VaultFileOk).value, fixtureCards);

      final r = codec.encodeRecent(fixtureRecent, dek)!;
      expect((codec.decodeRecent(r, dek) as VaultFileOk).value, fixtureRecent);
    });

    test('ad20_plaintext_json_has_ad20_key_order_without_whitespace', () {
      final cards = utf8.decode(
        open(codec.encodeCards(fixtureCards, dek)!, 'cards'),
      );
      final recent = utf8.decode(
        open(codec.encodeRecent(fixtureRecent, dek)!, 'recent'),
      );

      expect(
        cards,
        startsWith(
          '{"v":1,"cards":[{"id":"3f2b8c1e-5d4a-4e6f-9a7b-1c2d3e4f5a6b",'
          '"title":"Example Mail","username":"alice@example.com",'
          '"password":"Fake-Pass-0001!","note":"","createdAt":1762300800000},',
        ),
      );
      expect(cards, isNot(contains('\n')));
      expect(
        recent,
        '{"v":1,"items":[{"password":"K9#mVq2!xLp7wZr",'
        '"recordedAt":1762390800000}]}',
      );
    });

    test('ad20_empty_lists_round_trip', () {
      final cards = codec.encodeCards(const [], dek)!;
      final recent = codec.encodeRecent(const [], dek)!;

      expect(utf8.decode(open(cards, 'cards')), '{"v":1,"cards":[]}');
      expect(utf8.decode(open(recent, 'recent')), '{"v":1,"items":[]}');
      expect((codec.decodeCards(cards, dek) as VaultFileOk).value, isEmpty);
      expect((codec.decodeRecent(recent, dek) as VaultFileOk).value, isEmpty);
    });

    test('ad20_encode_with_wrong_dek_length_returns_null', () {
      final short = sodium.secureCopy(seq(0, 16));
      addTearDown(short.dispose);

      expect(codec.encodeCards(fixtureCards, short), isNull);
      expect(codec.encodeRecent(fixtureRecent, short), isNull);
    });
  });

  group('file hỏng → corrupt', () {
    void expectCorrupt(VaultFileResult<Object?> result, [String? reason]) =>
        expect(result, isA<VaultFileCorrupt<Object?>>(), reason: reason);

    test('ad20_shorter_than_nonce_plus_tag_is_corrupt', () {
      final file = vaultFixture('cards');
      for (final n in [0, 1, 24, 39]) {
        expectCorrupt(codec.decodeCards(file.sublist(0, n), dek), '$n byte');
        expectCorrupt(codec.decodeRecent(file.sublist(0, n), dek), '$n byte');
      }
      // Đúng 40 byte nhưng tag sai.
      expectCorrupt(codec.decodeCards(Uint8List(40), dek), '40 byte 0');
    });

    test('ad20_flipped_tag_ciphertext_or_nonce_is_corrupt', () {
      final golden = vaultFixture('cards');
      for (final i in [0, 23, 24, 100, golden.length - 1]) {
        final file = Uint8List.fromList(golden);
        file[i] ^= 0x01;
        expectCorrupt(codec.decodeCards(file, dek), 'byte $i');
      }
    });

    test('ad20_other_dek_is_corrupt', () {
      final other = sodium.secureCopy(seq(0x01, 32));
      addTearDown(other.dispose);

      expectCorrupt(codec.decodeCards(vaultFixture('cards'), other));
      expectCorrupt(codec.decodeRecent(vaultFixture('recent'), other));
    });

    test('ad20_swapped_associated_data_is_corrupt', () {
      expectCorrupt(codec.decodeRecent(vaultFixture('cards'), dek));
      expectCorrupt(codec.decodeCards(vaultFixture('recent'), dek));
    });

    test('ad20_invalid_json_or_utf8_is_corrupt', () {
      for (final text in ['', '{', 'null', '[]', '"x"', '{"v":1,"cards":']) {
        expectCorrupt(codec.decodeCards(seal(text, 'cards'), dek), text);
        expectCorrupt(codec.decodeRecent(seal(text, 'recent'), dek), text);
      }
      final badUtf8 = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
        message: Uint8List.fromList([0x7b, 0xff, 0x7d]),
        nonce: Uint8List(24),
        key: dek,
        additionalData: ascii.encode('PAK-VAULT/cards/v1'),
      );
      expectCorrupt(
        codec.decodeCards(
          Uint8List.fromList([...Uint8List(24), ...badUtf8]),
          dek,
        ),
      );
    });

    test('ad20_unknown_or_missing_version_is_corrupt', () {
      for (final v in [0, 2, '1', 1.0, null, true]) {
        expectCorrupt(decodeCardsJson({'v': v, 'cards': <Object?>[]}), '$v');
        expectCorrupt(decodeRecentJson({'v': v, 'items': <Object?>[]}), '$v');
      }
      expectCorrupt(decodeCardsJson({'cards': <Object?>[]}), 'thiếu v');
      expectCorrupt(decodeRecentJson({'items': <Object?>[]}), 'thiếu v');
    });

    test('ad20_missing_or_wrong_list_is_corrupt', () {
      expectCorrupt(decodeCardsJson({'v': 1}));
      expectCorrupt(decodeCardsJson({'v': 1, 'items': <Object?>[]}));
      expectCorrupt(decodeCardsJson({'v': 1, 'cards': null}));
      expectCorrupt(decodeCardsJson({'v': 1, 'cards': <String, Object?>{}}));
      expectCorrupt(
        decodeCardsJson({
          'v': 1,
          'cards': [1],
        }),
      );
      expectCorrupt(decodeRecentJson({'v': 1}));
      expectCorrupt(decodeRecentJson({'v': 1, 'cards': <Object?>[]}));
      expectCorrupt(decodeRecentJson({'v': 1, 'items': 'x'}));
      expectCorrupt(
        decodeRecentJson({
          'v': 1,
          'items': [null],
        }),
      );
    });

    test('ad20_card_missing_key_is_corrupt', () {
      for (final key in cardJson().keys) {
        final card = cardJson()..remove(key);
        expectCorrupt(
          decodeCardsJson({
            'v': 1,
            'cards': [cardJson(), card],
          }),
          'thiếu $key',
        );
      }
    });

    test('ad20_card_wrong_type_is_corrupt', () {
      final cases = <String, Object?>{
        'note': null,
        'title': 1,
        'username': false,
        'password': <Object?>[],
        'createdAt': 3.0,
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        expectCorrupt(
          decodeCardsJson({
            'v': 1,
            'cards': [cardJson()..[key] = value],
          }),
          '$key = $value',
        );
      }
      for (final at in [-1, '1762300800000', null]) {
        expectCorrupt(
          decodeCardsJson({
            'v': 1,
            'cards': [cardJson()..['createdAt'] = at],
          }),
          'createdAt = $at',
        );
      }
    });

    test('ad20_card_id_must_be_lowercase_uuid_v4', () {
      for (final id in [
        '3F2B8C1E-5D4A-4E6F-9A7B-1C2D3E4F5A6B',
        '3f2b8c1e-5d4a-1e6f-9a7b-1c2d3e4f5a6b',
        '3f2b8c1e-5d4a-4e6f-7a7b-1c2d3e4f5a6b',
        '3f2b8c1e5d4a4e6f9a7b1c2d3e4f5a6b',
        '3f2b8c1e-5d4a-4e6f-9a7b-1c2d3e4f5a6',
        '',
        42,
      ]) {
        expectCorrupt(
          decodeCardsJson({
            'v': 1,
            'cards': [cardJson()..['id'] = id],
          }),
          'id $id',
        );
      }
    });

    test('ad20_recent_missing_key_or_wrong_type_is_corrupt', () {
      for (final key in recentJson().keys) {
        expectCorrupt(
          decodeRecentJson({
            'v': 1,
            'items': [recentJson()..remove(key)],
          }),
          'thiếu $key',
        );
      }
      for (final (key, value) in [
        ('password', null),
        ('password', 7),
        ('recordedAt', 3.0),
        ('recordedAt', -1),
        ('recordedAt', null),
      ]) {
        expectCorrupt(
          decodeRecentJson({
            'v': 1,
            'items': [recentJson()..[key] = value],
          }),
          '$key = $value',
        );
      }
    });
  });

  test('ad20_unknown_keys_are_ignored', () {
    final cards = decodeCardsJson({
      'v': 1,
      'extra': true,
      'cards': [cardJson()..['color'] = 'red'],
    });
    final recent = decodeRecentJson({
      'v': 1,
      'items': [recentJson()..['x'] = 1],
      'y': null,
    });

    expect((cards as VaultFileOk).value, [fixtureCards.first]);
    expect((recent as VaultFileOk).value, fixtureRecent);
  });

  test('ad20_decoded_lists_are_unmodifiable', () {
    final cards = (codec.decodeCards(
      vaultFixture('cards'),
      dek,
    ) as VaultFileOk<List<VaultCard>>).value;

    expect(() => cards.add(fixtureCards.first), throwsUnsupportedError);
  });
}
