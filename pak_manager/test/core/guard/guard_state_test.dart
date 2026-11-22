import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/guard/guard_state.dart';

const _waiting = GuardState(
  failCount: 6,
  waitBootId: 'fake-boot-1',
  waitStartMono: 1800000,
);

void main() {
  test('fr04_constants_are_fixed', () {
    expect(maxAttempts, 10);
    expect(waitFromAttempt, 5);
    expect(waitDuration, const Duration(minutes: 30));
  });

  test('ad08_initial_has_full_attempts_and_no_wait', () {
    expect(GuardState.initial.failCount, 0);
    expect(GuardState.initial.waitBootId, isNull);
    expect(GuardState.initial.waitStartMono, isNull);
    expect(GuardState.initial.wiping, isFalse);
    expect(GuardState.initial.attemptsLeft, 10);
    expect(GuardState.initial.exhausted, isFalse);
  });

  test('fr04_ad08_after_attempt_counts_up_and_caps_at_max', () {
    var state = GuardState.initial;
    for (var i = 1; i <= maxAttempts; i++) {
      state = state.afterAttempt();
      expect(state.failCount, i);
      expect(state.attemptsLeft, maxAttempts - i);
      expect(state.exhausted, i == maxAttempts);
    }
    expect(state.afterAttempt().failCount, maxAttempts);
    expect(state.afterAttempt(), state);
  });

  test('ad08_after_attempt_keeps_wait_and_wiping_fields', () {
    final next = _waiting.afterAttempt();
    expect(next.failCount, 7);
    expect(next.waitBootId, 'fake-boot-1');
    expect(next.waitStartMono, 1800000);
    expect(next.wiping, isFalse);

    const wiping = GuardState(failCount: 2, wiping: true);
    expect(wiping.afterAttempt().wiping, isTrue);
  });

  test('fr05_ad08_after_success_resets_count_and_clears_wait', () {
    final next = _waiting.afterSuccess();
    expect(next, GuardState.initial);
    expect(const GuardState(failCount: 10).afterSuccess(), GuardState.initial);
    // Không đụng cờ xóa dở dang (story 2.3).
    expect(
      const GuardState(failCount: 4, wiping: true).afterSuccess().wiping,
      isTrue,
    );
  });

  test('ad08_equality_covers_every_field', () {
    expect(
      const GuardState(failCount: 6, waitBootId: 'fake-boot-1'),
      isNot(_waiting),
    );
    expect(
      const GuardState(
        failCount: 6,
        waitBootId: 'fake-boot-1',
        waitStartMono: 1800000,
      ),
      _waiting,
    );
    expect(
      const GuardState(
        failCount: 6,
        waitBootId: 'fake-boot-1',
        waitStartMono: 1800000,
      ).hashCode,
      _waiting.hashCode,
    );
    expect(
      const GuardState(failCount: 0, wiping: true),
      isNot(GuardState.initial),
    );
  });

  group('wait mark', () {
    const boot = 'fake-boot-1';
    const mark = 1800000;
    final fullMs = waitDuration.inMilliseconds;

    test('fr04_in_wait_range_is_five_to_nine', () {
      for (var n = 0; n <= maxAttempts; n++) {
        expect(GuardState(failCount: n).inWaitRange, n >= 5 && n <= 9);
      }
    });

    test('ad08_with_wait_mark_sets_pair_and_keeps_other_fields', () {
      const base = GuardState(failCount: 5, wiping: true);
      final marked = base.withWaitMark('fake-boot-2', 42);
      expect(marked.failCount, 5);
      expect(marked.waitBootId, 'fake-boot-2');
      expect(marked.waitStartMono, 42);
      expect(marked.wiping, isTrue);
      // Ghi đè mốc cũ.
      expect(_waiting.withWaitMark(boot, 99).waitStartMono, 99);
    });

    test('ad08_reanchored_outside_wait_range_is_null', () {
      for (final n in [0, 1, 4, 10]) {
        expect(GuardState(failCount: n).reanchored(boot, 5), isNull);
        expect(
          GuardState(
            failCount: n,
            waitBootId: 'old-boot',
            waitStartMono: mark,
          ).reanchored(boot, 5),
          isNull,
        );
      }
    });

    test('ad08_reanchored_valid_mark_is_null', () {
      expect(_waiting.reanchored(boot, mark), isNull);
      expect(_waiting.reanchored(boot, mark + fullMs * 3), isNull);
    });

    test('ad08_reanchored_missing_or_partial_mark_anchors_now', () {
      for (final state in const [
        GuardState(failCount: 7),
        GuardState(failCount: 7, waitBootId: boot),
        GuardState(failCount: 7, waitStartMono: mark),
      ]) {
        expect(
          state.reanchored(boot, 5000),
          const GuardState(failCount: 7, waitBootId: boot, waitStartMono: 5000),
        );
      }
    });

    test('tc03_ad08_reanchored_other_boot_anchors_now', () {
      // Mono mới lớn hơn mốc vẫn neo lại: khác lần khởi động.
      expect(
        _waiting.reanchored('fake-boot-2', mark + 10),
        _waiting.withWaitMark('fake-boot-2', mark + 10),
      );
    });

    test('tc03_ad08_reanchored_mono_backwards_anchors_now', () {
      expect(
        _waiting.reanchored(boot, mark - 1),
        _waiting.withWaitMark(boot, mark - 1),
      );
    });

    test('ad08_reanchored_keeps_wiping', () {
      const state = GuardState(failCount: 6, wiping: true);
      expect(state.reanchored(boot, 1)!.wiping, isTrue);
    });

    test('fr04_ad09_wait_remaining_counts_down_from_full', () {
      expect(_waiting.waitRemaining(mark), waitDuration);
      expect(
        _waiting.waitRemaining(mark + 12 * 60 * 1000),
        const Duration(minutes: 18),
      );
      expect(
        _waiting.waitRemaining(mark + fullMs - 1),
        const Duration(milliseconds: 1),
      );
    });

    test('fr04_ad09_wait_remaining_bounds_zero', () {
      expect(_waiting.waitRemaining(mark + fullMs), Duration.zero);
      expect(_waiting.waitRemaining(mark + fullMs * 10), Duration.zero);
    });

    test('tc03_ad09_wait_remaining_mono_backwards_unanchored_is_full', () {
      expect(_waiting.waitRemaining(mark - 1), waitDuration);
      expect(_waiting.waitRemaining(0), waitDuration);
    });

    test('ad08_wait_remaining_missing_mark_is_full', () {
      expect(const GuardState(failCount: 5).waitRemaining(10), waitDuration);
      expect(
        const GuardState(failCount: 5, waitStartMono: 10).waitRemaining(10),
        waitDuration,
      );
    });

    test('fr04_wait_remaining_outside_range_is_zero', () {
      for (final n in [0, 4, 10]) {
        expect(
          GuardState(
            failCount: n,
            waitBootId: boot,
            waitStartMono: mark,
          ).waitRemaining(mark),
          Duration.zero,
        );
      }
    });
  });

  test('ad21_with_wiping_sets_flag_and_keeps_count_and_mark', () {
    final next = _waiting.withWiping();
    expect(next.wiping, isTrue);
    expect(next.failCount, 6);
    expect(next.waitBootId, 'fake-boot-1');
    expect(next.waitStartMono, 1800000);
    expect(const GuardState(failCount: 10).withWiping().failCount, 10);
  });

  test('ad21_is_initial_only_for_the_clean_state', () {
    expect(GuardState.initial.isInitial, isTrue);
    expect(const GuardState(failCount: 0).isInitial, isTrue);
    expect(const GuardState(failCount: 1).isInitial, isFalse);
    expect(const GuardState(failCount: 0, wiping: true).isInitial, isFalse);
    expect(_waiting.isInitial, isFalse);
    expect(
      const GuardState(
        failCount: 0,
        waitBootId: 'fake-boot-1',
        waitStartMono: 1,
      ).isInitial,
      isFalse,
    );
  });
}
