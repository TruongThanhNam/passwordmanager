import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/model/recent_entry.dart';
import 'package:pak_manager/core/model/vault_card.dart';
import 'package:pak_manager/services/vault_session.dart';

import '../support/account_fakes.dart';

void main() {
  const card = VaultCard(
    id: '3f2b8c1e-5d4a-4e6f-9a7b-1c2d3e4f5a6b',
    title: 'Example Mail',
    username: 'alice@example.com',
    password: 'Fake-Pass-0001',
    note: '',
    createdAt: 1762300800000,
  );
  const entry = RecentEntry(password: 'K9mVq2xLp7wZr00', recordedAt: 1);

  VaultSession sessionWith([FakeSecureKey? dek]) => VaultSession(
    dek: dek ?? FakeSecureKey(),
    cards: const [card],
    recent: const [entry],
  );

  test('ad22_vault_session_to_string_hides_secrets', () {
    final session = sessionWith();

    final text = session.toString();
    expect(text, 'VaultSession(cards: 1, recent: 1)');
    expect(text, isNot(contains('Fake-Pass')));
    expect(text, isNot(contains('K9mVq2')));
    expect(session.readCards().toString(), isNot(contains('Fake-Pass')));
    session.lock();
  });

  test('fr49_nfr4_lock_destroys_dek_and_drops_plaintext', () {
    final dek = FakeSecureKey();
    final session = sessionWith(dek);
    expect(session.isLocked, isFalse);
    expect((session.readCards() as SessionOk<List<VaultCard>>).value, [card]);

    session.lock();

    expect(dek.disposed, isTrue);
    expect(session.isLocked, isTrue);
    expect(session.readCards(), isA<SessionLocked<List<VaultCard>>>());
    expect(session.readRecent(), isA<SessionLocked<List<RecentEntry>>>());
    expect(session.toString(), 'VaultSession(locked)');
    // Gọi lại không lỗi.
    session.lock();
  });

  test('ad22_session_lists_are_read_only', () {
    final session = sessionWith();

    final cards = (session.readCards() as SessionOk<List<VaultCard>>).value;
    final recent = (session.readRecent() as SessionOk<List<RecentEntry>>).value;
    expect(() => cards.add(card), throwsUnsupportedError);
    expect(() => recent.clear(), throwsUnsupportedError);
    session.lock();
  });

  test('ad6_run_after_lock_returns_locked_and_skips_op', () async {
    final session = sessionWith()..lock();
    var ran = false;

    final result = await session.run((_) => ran = true);

    expect(result, isA<SessionLocked<bool>>());
    expect(ran, isFalse);
  });

  test('ad6_run_is_sequential_and_passes_dek', () async {
    final dek = FakeSecureKey();
    final session = sessionWith(dek);
    final log = <String>[];
    final gate = Completer<void>();

    final first = session.run((key) async {
      expect(key, same(dek));
      log.add('a-start');
      await gate.future;
      log.add('a-end');
      return 1;
    });
    final second = session.run((_) {
      log.add('b');
      return 2;
    });
    await pumpEventQueue();
    expect(log, ['a-start']);

    gate.complete();
    expect((await first as SessionOk<int>).value, 1);
    expect((await second as SessionOk<int>).value, 2);
    expect(log, ['a-start', 'a-end', 'b']);
    session.lock();
  });

  test('ad6_op_error_propagates_and_queue_continues', () async {
    final session = sessionWith();

    await expectLater(
      session.run<int>((_) => throw StateError('fake')),
      throwsStateError,
    );
    expect(await session.run((_) => 3), isA<SessionOk<int>>());
    session.lock();
  });

  test('ad9_idle_waits_running_op_then_lock_cancels_queued', () async {
    final dek = FakeSecureKey();
    final session = sessionWith(dek);
    final gate = Completer<void>();
    var runningDone = false;
    var queuedRan = false;

    final running = session.run((_) async {
      await gate.future;
      // DEK chưa bị hủy khi op đang chạy.
      expect(dek.disposed, isFalse);
      runningDone = true;
    });
    final queued = session.run((_) => queuedRan = true);
    await pumpEventQueue();

    var idle = false;
    final waiting = session.idle().then((_) => idle = true);
    await pumpEventQueue();
    expect(idle, isFalse);

    gate.complete();
    await waiting;
    expect(runningDone, isTrue);
    session.lock();

    expect(await running, isA<SessionOk<void>>());
    expect(await queued, isA<SessionLocked<bool>>());
    expect(queuedRan, isFalse);
    expect(dek.disposed, isTrue);
  });

  test('ad6_idle_without_lock_resumes_queue', () async {
    final session = sessionWith();
    final gate = Completer<void>();
    unawaited(session.run((_) => gate.future));
    final queued = session.run((_) => 5);
    final waiting = session.idle();
    gate.complete();
    await waiting;

    expect((await queued as SessionOk<int>).value, 5);
    session.lock();
  });

  test('ad6_idle_on_idle_session_completes', () async {
    final session = sessionWith();
    await session.idle();
    session.lock();
    await session.idle();
  });
}
