import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../crypto/random_source.dart';
import '../crypto/wipe.dart';
import '../model/recent_entry.dart';
import '../model/vault_card.dart';

/// Kết quả giải mã một file dữ liệu vault.
sealed class VaultFileResult<T> {
  const VaultFileResult();
}

final class VaultFileOk<T> extends VaultFileResult<T> {
  const VaultFileOk(this.value);

  final T value;
}

/// File hỏng (AEAD lỗi, JSON sai, thiếu key, sai kiểu, `v` lạ); không kèm
/// thông điệp (AD-20).
final class VaultFileCorrupt<T> extends VaultFileResult<T> {
  const VaultFileCorrupt();
}

/// Codec duy nhất của hai file `vault/cards` và `vault/recent` (AD-20).
///
/// Mỗi file là `nonce[24] ‖ ciphertext‖tag`, XChaCha20-Poly1305 bằng DEK,
/// nonce mới mỗi lần ghi, AD `PAK-VAULT/<loại>/v1`. Bản rõ là JSON UTF-8,
/// không khoảng trắng, thứ tự key cố định:
///
/// ```json
/// cards:  {"v":1,"cards":[{"id","title","username","password","note",
///          "createdAt"}]}
/// recent: {"v":1,"items":[{"password","recordedAt"}]}
/// ```
///
/// `id` là UUIDv4 chữ thường; thời gian là UTC epoch ms (int ≥ 0); note
/// rỗng là `""`; mọi key bắt buộc, key lạ bị bỏ qua. Không method nào ném.
final class VaultFileCodec {
  VaultFileCodec(this._sodium, this._random);

  final SodiumSumo _sodium;
  final RandomSource _random;

  static const int version = 1;
  static const int _nonceBytes = 24;
  static const int _tagBytes = 16;

  static final Uint8List _adCards = ascii.encode('PAK-VAULT/cards/v1');
  static final Uint8List _adRecent = ascii.encode('PAK-VAULT/recent/v1');

  static final RegExp _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  /// `nonce‖ct` của [cards]; `null` khi không mã hóa được (DEK sai độ dài
  /// hoặc đã dispose) hoặc khi có card mà [decodeCards] sẽ từ chối (id không
  /// phải UUIDv4 chữ thường, `createdAt` âm).
  Uint8List? encodeCards(List<VaultCard> cards, SecureKey dek) => _encrypt(
    'cards',
    [
      for (final c in cards)
        <String, Object?>{
          'id': c.id,
          'title': c.title,
          'username': c.username,
          'password': c.password,
          'note': c.note,
          'createdAt': c.createdAt,
        },
    ],
    _card,
    _adCards,
    dek,
  );

  /// `nonce‖ct` của [items]; `null` khi không mã hóa được hoặc khi có mục
  /// mà [decodeRecent] sẽ từ chối (`recordedAt` âm).
  Uint8List? encodeRecent(List<RecentEntry> items, SecureKey dek) => _encrypt(
    'items',
    [
      for (final e in items)
        <String, Object?>{'password': e.password, 'recordedAt': e.recordedAt},
    ],
    _recent,
    _adRecent,
    dek,
  );

  VaultFileResult<List<VaultCard>> decodeCards(
    List<int> bytes,
    SecureKey dek,
  ) => _decrypt(bytes, dek, _adCards, 'cards', _card);

  VaultFileResult<List<RecentEntry>> decodeRecent(
    List<int> bytes,
    SecureKey dek,
  ) => _decrypt(bytes, dek, _adRecent, 'items', _recent);

  /// Mỗi mục phải qua đúng luật của bản decode ([check] ≠ `null`), để không
  /// ghi ra file mà lần mở khóa sau đọc thành `corrupt`.
  Uint8List? _encrypt(
    String listKey,
    List<Map<String, Object?>> entries,
    Object? Function(Object?) check,
    Uint8List ad,
    SecureKey dek,
  ) {
    if (entries.any((e) => check(e) == null)) {
      return null;
    }
    Uint8List? plain;
    try {
      plain = utf8.encode(
        jsonEncode(<String, Object?>{'v': version, listKey: entries}),
      );
      final nonce = _random.bytes(_nonceBytes);
      if (nonce.length != _nonceBytes) {
        return null;
      }
      final ct = _sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
        message: plain,
        nonce: nonce,
        key: dek,
        additionalData: ad,
      );
      return Uint8List(_nonceBytes + ct.length)
        ..setAll(0, nonce)
        ..setAll(_nonceBytes, ct);
    } on Object {
      return null;
    } finally {
      if (plain != null) {
        wipe(plain);
      }
    }
  }

  VaultFileResult<List<T>> _decrypt<T>(
    List<int> bytes,
    SecureKey dek,
    Uint8List ad,
    String listKey,
    T? Function(Object?) item,
  ) {
    Uint8List? plain;
    try {
      if (bytes.length < _nonceBytes + _tagBytes) {
        return VaultFileCorrupt<List<T>>();
      }
      final all = Uint8List.fromList(bytes);
      plain = _sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
        cipherText: Uint8List.sublistView(all, _nonceBytes),
        nonce: Uint8List.sublistView(all, 0, _nonceBytes),
        key: dek,
        additionalData: ad,
      );
      final root = jsonDecode(utf8.decode(plain));
      if (root is! Map<String, Object?> ||
          !_isInt(root['v'], version) ||
          root[listKey] is! List<Object?>) {
        return VaultFileCorrupt<List<T>>();
      }
      final out = <T>[];
      for (final raw in root[listKey]! as List<Object?>) {
        final parsed = item(raw);
        if (parsed == null) {
          return VaultFileCorrupt<List<T>>();
        }
        out.add(parsed);
      }
      return VaultFileOk<List<T>>(List<T>.unmodifiable(out));
    } on Object {
      return VaultFileCorrupt<List<T>>();
    } finally {
      if (plain != null) {
        wipe(plain);
      }
    }
  }

  static VaultCard? _card(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    return switch ((
      raw['id'],
      raw['title'],
      raw['username'],
      raw['password'],
      raw['note'],
      raw['createdAt'],
    )) {
      (
        final String id,
        final String title,
        final String username,
        final String password,
        final String note,
        final int createdAt,
      )
          when _uuidV4.hasMatch(id) && createdAt >= 0 =>
        VaultCard(
          id: id,
          title: title,
          username: username,
          password: password,
          note: note,
          createdAt: createdAt,
        ),
      _ => null,
    };
  }

  static RecentEntry? _recent(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    return switch ((raw['password'], raw['recordedAt'])) {
      (final String password, final int recordedAt) when recordedAt >= 0 =>
        RecentEntry(password: password, recordedAt: recordedAt),
      _ => null,
    };
  }

  static bool _isInt(Object? value, int expected) =>
      value is int && value == expected;
}
