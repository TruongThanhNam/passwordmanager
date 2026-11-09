// Đầu vào cố định của fixture `test/fixtures/vault/v1/` (xem README.md cạnh
// fixture và tool/fixtures/gen_vault_v1.dart) cùng các fake dùng chung cho
// test crypto/codec của story 1.4. Chỉ dữ liệu giả.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pak_manager/core/crypto/kdf.dart';
import 'package:pak_manager/core/crypto/random_source.dart';
import 'package:pak_manager/core/model/recent_entry.dart';
import 'package:pak_manager/core/model/vault_card.dart';
import 'package:sodium/sodium_sumo.dart';

const vaultFixtureDir = 'test/fixtures/vault/v1';

Uint8List vaultFixture(String name) =>
    File('$vaultFixtureDir/$name').readAsBytesSync();

/// Dãy byte cố định `start, start+1, …` như script sinh fixture.
Uint8List seq(int start, int length) =>
    Uint8List.fromList([for (var i = 0; i < length; i++) (start + i) & 0xff]);

Uint8List fixturePassword() => ascii.encode('fixture-only correct horse 42');

const fixtureParams = KdfParams(2, 19 * mib);

Uint8List fixtureDek() => seq(0x00, 32);
Uint8List fixtureSalt() => seq(0x20, 16);
Uint8List fixtureWrapNonce() => seq(0x40, 24);
Uint8List fixtureCardsNonce() => seq(0x60, 24);
Uint8List fixtureRecentNonce() => seq(0x80, 24);

const fixtureCards = [
  VaultCard(
    id: '3f2b8c1e-5d4a-4e6f-9a7b-1c2d3e4f5a6b',
    title: 'Example Mail',
    username: 'alice@example.com',
    password: 'Fake-Pass-0001!',
    note: '',
    createdAt: 1762300800000,
  ),
  VaultCard(
    id: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
    title: 'Ngân hàng giả',
    username: 'nguyen.van.a',
    password: 'p@ss word ~ demo',
    note: 'Ghi chú: dữ liệu giả, không dùng thật.',
    createdAt: 1762387200000,
  ),
];

const fixtureRecent = [
  RecentEntry(password: 'K9#mVq2!xLp7wZr', recordedAt: 1762390800000),
];

/// [RandomSource] trả lần lượt các buffer cho trước; hết thì ném.
final class QueueRandomSource implements RandomSource {
  QueueRandomSource(Iterable<Uint8List> outputs) : _outputs = Queue.of(outputs);

  final Queue<Uint8List> _outputs;
  final List<int> requested = [];

  @override
  Uint8List bytes(int length) {
    requested.add(length);
    final next = _outputs.removeFirst();
    if (next.length != length) {
      throw StateError('cần $length byte, fake có ${next.length}');
    }
    return Uint8List.fromList(next);
  }
}

/// Khởi tạo libsodium một lần cho mỗi file test.
Future<SodiumSumo> initSodium() async => await SodiumSumoInit.init();
