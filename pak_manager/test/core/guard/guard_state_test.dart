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
}
