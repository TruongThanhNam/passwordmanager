import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/services/session_controller.dart';
import 'package:pak_manager/services/vault_session.dart';

import '../support/account_fakes.dart';

/// Controller có mọi hook ghi vào [log].
SessionController _logged(
  List<String> log, {
  Future<void> Function()? flushDraft,
}) => SessionController(
  flushDraft: flushDraft ?? () async => log.add('flushDraft'),
  awaitPendingWrites: () async => log.add('awaitPendingWrites'),
  cancelUnstarted: () async => log.add('cancelUnstarted'),
  clearClipboardIfOurs: () async => log.add('clearClipboard'),
);

void main() {
  test('ad9_enter_takes_session_and_bumps_epoch', () {
    final controller = SessionController();
    var notified = 0;
    controller.addListener(() => notified++);
    final session = fakeSession();

    controller.enter(session);

    expect(controller.session, same(session));
    expect(controller.epoch, 1);
    expect(notified, 1);
    controller.dispose();
  });

  test('ad9_enter_locks_previous_session', () {
    final controller = SessionController();
    final oldDek = FakeSecureKey();
    controller
      ..enter(fakeSession(oldDek))
      ..enter(fakeSession());

    expect(oldDek.disposed, isTrue);
    expect(controller.epoch, 2);
    controller.dispose();
  });

  test('fr49_ad9_lock_runs_steps_in_order', () async {
    final log = <String>[];
    final dek = FakeSecureKey();
    final controller = _logged(log);
    controller
      ..enter(fakeSession(dek))
      ..addListener(() => log.add('notify(epoch ${controller.epoch})'));
    final session = controller.session!;

    await controller.lock();

    // `session.idle` chạy song song với awaitPendingWrites.
    expect(log, [
      'flushDraft',
      'awaitPendingWrites',
      'cancelUnstarted',
      'clearClipboard',
      'notify(epoch 2)',
    ]);
    expect(dek.disposed, isTrue);
    expect(session.isLocked, isTrue);
    expect(controller.session, isNull);
    expect(controller.epoch, 2);
  });

  test('ad9_session_locked_before_clipboard_step', () async {
    late bool lockedAtClipboard;
    final session = fakeSession();
    final controller = SessionController(
      clearClipboardIfOurs: () async => lockedAtClipboard = session.isLocked,
    )..enter(session);

    await controller.lock();
    expect(lockedAtClipboard, isTrue);
  });

  test('ad9_lock_waits_running_op_before_destroying_dek', () async {
    final dek = FakeSecureKey();
    final controller = SessionController()..enter(fakeSession(dek));
    final session = controller.session!;
    final gate = Completer<void>();
    final running = session.run((_) => gate.future);
    final queued = session.run((_) => 1);
    await pumpEventQueue();

    var locked = false;
    final locking = controller.lock().then((_) => locked = true);
    await pumpEventQueue();
    expect(locked, isFalse);
    expect(dek.disposed, isFalse);

    gate.complete();
    await locking;
    expect(dek.disposed, isTrue);
    expect(await running, isA<SessionOk<void>>());
    expect(await queued, isA<SessionLocked<int>>());
  });

  test('ad9_slow_cancel_hook_does_not_let_queued_op_run', () async {
    final dek = FakeSecureKey();
    final controller = SessionController(
      cancelUnstarted: () => Future<void>.delayed(Duration.zero),
    )..enter(fakeSession(dek));
    final session = controller.session!;
    final gate = Completer<void>();
    final running = session.run((_) => gate.future);
    var queuedRan = false;
    final queued = session.run((_) => queuedRan = true);
    await pumpEventQueue();

    final locking = controller.lock();
    gate.complete();
    await locking;

    expect(await running, isA<SessionOk<void>>());
    expect(await queued, isA<SessionLocked<bool>>());
    expect(queuedRan, isFalse);
    expect(dek.disposed, isTrue);
  });

  test('ad9_overlapping_lock_returns_same_future_runs_once', () async {
    final log = <String>[];
    final controller = _logged(log)..enter(fakeSession());

    final a = controller.lock();
    final b = controller.lock();
    expect(identical(a, b), isTrue);
    await Future.wait([a, b]);

    expect(log.where((s) => s == 'flushDraft'), hasLength(1));
    expect(controller.epoch, 2);
  });

  test('ad9_hook_error_still_locks_and_bumps_epoch', () async {
    final log = <String>[];
    final dek = FakeSecureKey();
    final controller = _logged(
      log,
      flushDraft: () async => throw StateError('fake'),
    )..enter(fakeSession(dek));

    await controller.lock();

    expect(dek.disposed, isTrue);
    expect(controller.epoch, 2);
    expect(log, contains('cancelUnstarted'));
    expect(log, contains('clearClipboard'));
  });

  test('ad9_background_lock_skips_clipboard', () async {
    final log = <String>[];
    final controller = _logged(log)..enter(fakeSession());

    await controller.lock(foreground: false);

    expect(log, isNot(contains('clearClipboard')));
    expect(controller.session, isNull);
  });

  test('ad9_is_current_rejects_result_from_old_epoch', () async {
    final controller = SessionController()..enter(fakeSession());
    final before = controller.epoch;
    expect(controller.isCurrent(before), isTrue);

    await controller.lock();

    expect(controller.isCurrent(before), isFalse);
    expect(controller.isCurrent(controller.epoch), isTrue);
  });

  test('ad9_lock_without_session_is_noop', () async {
    final log = <String>[];
    final controller = _logged(log);
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.lock();

    expect(log, isEmpty);
    expect(controller.epoch, 0);
    expect(notified, 0);
  });

  test('ad9_dispose_locks_session', () {
    final dek = FakeSecureKey();
    SessionController()
      ..enter(fakeSession(dek))
      ..dispose();
    expect(dek.disposed, isTrue);
  });
}
