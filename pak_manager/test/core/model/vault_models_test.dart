import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/model/recent_entry.dart';
import 'package:pak_manager/core/model/vault_card.dart';

const _card = VaultCard(
  id: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
  title: 'Ngân hàng giả',
  username: 'nguyen.van.a',
  password: 'p@ss word ~ demo',
  note: 'Ghi chú giả',
  createdAt: 1762387200000,
);

const _entry = RecentEntry(
  password: 'K9#mVq2!xLp7wZr',
  recordedAt: 1762390800000,
);

void main() {
  test('ad22_vault_card_to_string_hides_secrets', () {
    final text = _card.toString();

    for (final secret in [
      _card.title,
      _card.username,
      _card.password,
      _card.note,
    ]) {
      expect(text, isNot(contains(secret)));
    }
    expect(text, contains(_card.id));
    expect(text, contains('${_card.createdAt}'));
  });

  test('ad22_recent_entry_to_string_hides_password', () {
    final text = _entry.toString();

    expect(text, isNot(contains(_entry.password)));
    expect(text, contains('${_entry.recordedAt}'));
  });

  test('ad20_vault_card_equality_covers_every_field', () {
    const same = VaultCard(
      id: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
      title: 'Ngân hàng giả',
      username: 'nguyen.van.a',
      password: 'p@ss word ~ demo',
      note: 'Ghi chú giả',
      createdAt: 1762387200000,
    );
    expect(_card, same);
    expect(_card.hashCode, same.hashCode);

    VaultCard change(String field) => VaultCard(
      id: field == 'id' ? 'x' : _card.id,
      title: field == 'title' ? 'x' : _card.title,
      username: field == 'username' ? 'x' : _card.username,
      password: field == 'password' ? 'x' : _card.password,
      note: field == 'note' ? 'x' : _card.note,
      createdAt: field == 'createdAt' ? 0 : _card.createdAt,
    );
    for (final field in [
      'id',
      'title',
      'username',
      'password',
      'note',
      'createdAt',
    ]) {
      expect(change(field), isNot(_card), reason: field);
    }
  });

  test('ad20_recent_entry_equality_covers_every_field', () {
    const same = RecentEntry(
      password: 'K9#mVq2!xLp7wZr',
      recordedAt: 1762390800000,
    );
    expect(_entry, same);
    expect(_entry.hashCode, same.hashCode);
    expect(
      const RecentEntry(password: 'x', recordedAt: 1762390800000),
      isNot(_entry),
    );
    expect(
      const RecentEntry(password: 'K9#mVq2!xLp7wZr', recordedAt: 0),
      isNot(_entry),
    );
  });
}
