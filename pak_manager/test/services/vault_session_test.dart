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

  test('ad22_vault_session_to_string_hides_secrets', () {
    final session = VaultSession(
      dek: FakeSecureKey(),
      cards: const [card],
      recent: const [entry],
    );

    final text = session.toString();
    expect(text, 'VaultSession(cards: 1, recent: 1)');
    expect(text, isNot(contains('Fake-Pass')));
    expect(text, isNot(contains('K9mVq2')));
    session.dispose();
  });

  test('ad22_dispose_destroys_dek_and_drops_plaintext', () {
    final dek = FakeSecureKey();
    final session = VaultSession(
      dek: dek,
      cards: const [card],
      recent: const [entry],
    );
    expect(session.isDisposed, isFalse);
    expect(session.cards, [card]);

    session.dispose();

    expect(dek.disposed, isTrue);
    expect(session.isDisposed, isTrue);
    expect(session.cards, isEmpty);
    expect(session.recent, isEmpty);
    expect(session.toString(), 'VaultSession(disposed)');
    // Gọi lại không lỗi.
    session.dispose();
  });

  test('ad22_session_lists_are_read_only', () {
    final session = VaultSession(
      dek: FakeSecureKey(),
      cards: [card],
      recent: [entry],
    );

    expect(() => session.cards.add(card), throwsUnsupportedError);
    expect(() => session.recent.clear(), throwsUnsupportedError);
    session.dispose();
  });
}
