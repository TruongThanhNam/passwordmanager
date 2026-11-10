import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/model/settings.dart';
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
    final release = Completer<void>();
    late VaultSession session;
    final controller = SessionController(
      flushDraft: () async => log.add('flushDraft'),
      awaitPendingWrites: () async => log.add('awaitPendingWrites'),
      cancelUnstarted: () async {
        log.add('cancelUnstarted');
        release.complete();
      },
      clearClipboardIfOurs: () async =>
          log.add('clearClipboard(locked: ${session.isLocked})'),
    );
    controller
      ..enter(fakeSession(dek))
      ..addListener(() => log.add('notify(epoch ${controller.epoch})'));
    session = controller.session!;
    // Op đang chạy chỉ xong sau cancelUnstarted: `idle` phải chờ nó.
    unawaited(
      session.run((_) async {
        await release.future;
        log.add('op done(locked: ${session.isLocked})');
      }),
    );
    await pumpEventQueue();

    await controller.lock();

    // idle chờ op xong sau cancelUnstarted, rồi mới lock() trước clipboard.
    expect(log, [
      'flushDraft',
      'awaitPendingWrites',
      'cancelUnstarted',
      'op done(locked: false)',
      'clearClipboard(locked: true)',
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

  group('autolock & giới hạn phiên (FR-14/15, AD-8)', () {
    late FakeClock clock;
    late FakeTimers timers;
    late Settings settings;
    late List<String> log;

    SessionController timed() => SessionController(
      clearClipboardIfOurs: () async => log.add('clearClipboard'),
      clock: clock,
      limits: () => settings,
      timerFactory: timers.create,
    );

    const min = Duration(minutes: 1);

    setUp(() {
      clock = FakeClock();
      timers = FakeTimers();
      settings = Settings.defaults;
      log = [];
    });

    Future<SessionController> entered() async {
      final c = timed()..enter(fakeSession());
      await pumpEventQueue();
      return c;
    }

    test('fr14_resume_within_autolock_keeps_session', () async {
      final c = await entered();
      c.enteredBackground();
      await pumpEventQueue();
      clock.advance(const Duration(minutes: 2, seconds: 59));
      expect(await c.evaluate(resumed: true), isFalse);
      await pumpEventQueue();
      expect(c.session, isNotNull);
      // Mốc nền đã xóa: lâu sau đó (vẫn trong hạn phiên) không khóa.
      clock.advance(const Duration(minutes: 5));
      expect(await c.evaluate(), isFalse);
      c.dispose();
    });

    test('fr14_resume_at_autolock_locks_in_foreground', () async {
      final c = await entered();
      c.enteredBackground();
      await pumpEventQueue();
      clock.advance(min * 3);
      expect(await c.evaluate(resumed: true), isTrue);
      await pumpEventQueue();
      expect(c.session, isNull);
      expect(log, ['clearClipboard']);
    });

    test('fr14_background_timer_locks_without_clipboard', () async {
      final c = await entered();
      c.enteredBackground();
      await pumpEventQueue();
      expect(timers.active.single.duration, min * 3);
      clock.advance(min * 3);
      timers.fireAll();
      await pumpEventQueue();
      expect(c.session, isNull);
      expect(log, isEmpty);
    });

    test('fr15_session_limit_locks_while_in_use_no_warning', () async {
      final c = await entered();
      expect(timers.active.single.duration, min * 10);
      clock.advance(min * 10);
      timers.fireAll();
      await pumpEventQueue();
      expect(c.session, isNull);
      expect(log, ['clearClipboard']);
    });

    test('ad8_early_timer_reschedules_by_clock', () async {
      final c = await entered();
      clock.advance(min * 4);
      timers.fireAll();
      await pumpEventQueue();
      expect(c.session, isNotNull);
      expect(timers.active.single.duration, min * 6);
      c.dispose();
      expect(timers.active, isEmpty);
    });

    test('fr14_fr15_first_deadline_wins', () async {
      final c = await entered();
      clock.advance(min * 8);
      c.enteredBackground();
      await pumpEventQueue();
      // Hạn phiên (còn 2 phút) đến trước autolock (3 phút).
      expect(timers.active.single.duration, min * 2);
      clock.advance(min * 2);
      timers.fireAll();
      await pumpEventQueue();
      expect(c.session, isNull);
      expect(log, isEmpty);
    });

    test('fr14_fr15_settings_change_applies_next_count_only', () async {
      final c = await entered();
      settings = settings.copyWith(sessionMin: 1, autolockMin: 1);
      clock.advance(min * 5);
      expect(await c.evaluate(), isFalse);
      c.enteredBackground();
      await pumpEventQueue();
      clock.advance(min * 1);
      expect(await c.evaluate(resumed: true), isTrue);
    });

    test('fr15_session_limit_snapshot_survives_settings_change', () async {
      final c = await entered();
      settings = settings.copyWith(sessionMin: 1);
      clock.advance(min * 9);
      expect(await c.evaluate(), isFalse);
      clock.advance(min * 1);
      expect(await c.evaluate(), isTrue);
    });

    test('ad9_expiry_waits_running_write', () async {
      final dek = FakeSecureKey();
      final c = timed()..enter(fakeSession(dek));
      await pumpEventQueue();
      final gate = Completer<void>();
      final running = c.session!.run((_) => gate.future);
      await pumpEventQueue();
      clock.advance(min * 10);
      timers.fireAll();
      await pumpEventQueue();
      expect(dek.disposed, isFalse);
      gate.complete();
      expect(await running, isA<SessionOk<void>>());
      await pumpEventQueue();
      expect(dek.disposed, isTrue);
    });

    test('ad8_clock_backwards_fails_closed', () async {
      final c = await entered();
      clock.ms -= 1;
      expect(await c.evaluate(), isTrue);
      await pumpEventQueue();
      expect(c.session, isNull);
    });

    test('ad8_clock_error_fails_closed', () async {
      final c = await entered();
      clock.error = StateError('fake');
      expect(await c.evaluate(), isTrue);
      await pumpEventQueue();
      expect(c.session, isNull);
    });

    test('ad8_clock_error_on_enter_fails_closed', () async {
      clock.error = StateError('fake');
      final c = timed()..enter(fakeSession());
      await pumpEventQueue();
      expect(c.session, isNull);
    });

    test('ad9_clock_result_after_epoch_change_is_dropped', () async {
      final c = await entered();
      final hold = Completer<void>();
      clock.hold = hold;
      final pending = c.evaluate();
      await pumpEventQueue();
      clock.hold = null;
      await c.lock();
      c.enter(fakeSession());
      await pumpEventQueue();
      final fresh = c.session;
      // Giá trị đã quá hạn của phiên cũ tới sau khi epoch đổi.
      clock.advance(min * 20);
      hold.complete();
      expect(await pending, isFalse);
      await pumpEventQueue();
      expect(c.session, same(fresh));
      c.dispose();
    });

    test('ad8_clock_backwards_vs_background_mark_fails_closed', () async {
      final c = await entered();
      clock.advance(min * 2);
      c.enteredBackground();
      await pumpEventQueue();
      clock.advance(-const Duration(minutes: 1));
      expect(await c.evaluate(resumed: true), isTrue);
      await pumpEventQueue();
      expect(c.session, isNull);
    });

    test('fr14_autolock_snapshot_survives_settings_change', () async {
      final c = await entered();
      c.enteredBackground();
      await pumpEventQueue();
      settings = settings.copyWith(autolockMin: 1);
      clock.advance(const Duration(minutes: 2, seconds: 59));
      expect(await c.evaluate(resumed: true), isFalse);
      c.dispose();
    });

    test('ad9_manual_lock_cancels_timer', () async {
      final c = await entered();
      expect(timers.active, hasLength(1));
      await c.lock();
      expect(timers.active, isEmpty);
    });

    test('ad8_without_clock_never_autolocks', () async {
      final c = SessionController()..enter(fakeSession());
      c.enteredBackground();
      expect(await c.evaluate(), isFalse);
      expect(c.session, isNotNull);
      c.dispose();
    });
  });
}
