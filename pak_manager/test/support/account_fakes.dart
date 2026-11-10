// Fake tự viết cho test UI tài khoản (story 1.6): không gọi libsodium thật,
// nên chạy được cả trên máy thiếu build hook `sodium`. Chỉ dữ liệu giả.

import 'dart:async';
import 'dart:typed_data';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/core/policy/password_policy.dart';
import 'package:pak_manager/core/policy/strength_estimator.dart';
import 'package:pak_manager/features/shared/pak_app.dart';
import 'package:pak_manager/features/shared/pak_buttons.dart';
import 'package:pak_manager/features/shared/providers.dart';
import 'package:pak_manager/services/account_service.dart';
import 'package:pak_manager/services/settings_store.dart';
import 'package:pak_manager/services/vault_session.dart';
import 'package:sodium/sodium_sumo.dart';

import '../core/policy/policy_test_support.dart';

/// `SecureKey` giả 32 byte, chỉ ghi nhận `dispose`.
final class FakeSecureKey implements SecureKey {
  bool disposed = false;

  @override
  int get length => 32;

  @override
  void dispose() => disposed = true;

  @override
  T runUnlockedSync<T>(SecureCallbackFn<T> callback, {bool writable = false}) =>
      callback(Uint8List(32));

  @override
  FutureOr<T> runUnlockedAsync<T>(
    SecureCallbackFn<FutureOr<T>> callback, {
    bool writable = false,
  }) => callback(Uint8List(32));

  @override
  Uint8List extractBytes() => Uint8List(32);

  @override
  SecureKey copy() => FakeSecureKey();
}

/// Phiên giả có DEK giả.
VaultSession fakeSession([FakeSecureKey? dek]) => VaultSession(
  dek: dek ?? FakeSecureKey(),
  cards: const [],
  recent: const [],
);

/// `AccountService` giả: `create`/`unlock` treo tới khi test gọi
/// [completeCreate]/[completeUnlock].
final class FakeAccountService implements AccountService {
  FakeAccountService({this.bootstrapResult = const BootstrapNoAccount()});

  final BootstrapResult bootstrapResult;

  /// Mật khẩu của từng lần gọi `create`.
  final List<String> createCalls = [];

  final List<Completer<CreateResult>> _pending = [];

  @override
  Future<BootstrapResult> bootstrap() async => bootstrapResult;

  @override
  Future<CreateResult> create(String password) {
    createCalls.add(password);
    final completer = Completer<CreateResult>();
    _pending.add(completer);
    return completer.future;
  }

  /// Trả kết quả cho lần `create` cũ nhất còn treo.
  void completeCreate(CreateResult result) =>
      _pending.removeAt(0).complete(result);

  /// Mật khẩu của từng lần gọi `unlock`.
  final List<String> unlockCalls = [];

  final List<Completer<UnlockResult>> _pendingUnlock = [];

  @override
  Future<UnlockResult> unlock(String password) {
    unlockCalls.add(password);
    final completer = Completer<UnlockResult>();
    _pendingUnlock.add(completer);
    return completer.future;
  }

  /// Trả kết quả cho lần `unlock` cũ nhất còn treo.
  void completeUnlock(UnlockResult result) =>
      _pendingUnlock.removeAt(0).complete(result);
}

/// Bộ ước lượng độ mạnh dùng chung (dựng từ điển một lần cho cả file test).
final sharedEstimator = StrengthEstimator();

/// Dựng app thật (`PakApp` → `SessionGate`) với provider giả. Mặc định: tiếng
/// Việt, sáng, chưa có tài khoản, luật với blocklist rỗng.
Future<void> pumpGateApp(
  WidgetTester tester, {
  BootstrapResult bootstrap = const BootstrapNoAccount(),
  AccountService? service,
  PasswordPolicy? policy,
  bool withPolicy = true,
  AppLanguage language = AppLanguage.vi,
}) async {
  final store = SettingsStore.inMemory(
    Settings.defaults.copyWith(
      language: language,
      appearance: Appearance.light,
    ),
  );
  addTearDown(store.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountServiceProvider.overrideWithValue(service),
        passwordPolicyProvider.overrideWithValue(
          withPolicy ? (policy ?? PasswordPolicy(emptyFilter())) : null,
        ),
        strengthEstimatorProvider.overrideWithValue(sharedEstimator),
        bootstrapResultProvider.overrideWithValue(bootstrap),
      ],
      child: PakApp(settings: store, androidSdkInt: 35),
    ),
  );
}

/// Bấm "Tạo tài khoản" ở S1 và chờ chuyển cảnh push xong.
Future<void> openCreateScreen(WidgetTester tester) async {
  await tester.tap(find.byType(PakPrimaryButton));
  await tester.pumpAndSettle();
}

/// Mật khẩu hợp lệ với blocklist rỗng (chỉ dữ liệu giả).
const validPassword = 'fake purple lantern 42 drift';

/// Từ S1: mở S2, tạo tài khoản với [session] (mặc định phiên giả) và chờ
/// khung 3 tab hiện.
Future<void> createAndEnterShell(
  WidgetTester tester,
  FakeAccountService service, [
  VaultSession? session,
]) async {
  await openCreateScreen(tester);
  await tester.enterText(
    find.byKey(const ValueKey('create.field.main')),
    validPassword,
  );
  await tester.enterText(
    find.byKey(const ValueKey('create.field.confirm')),
    validPassword,
  );
  await tester.pump();
  await tester.tap(find.byType(PakPrimaryButton));
  await tester.pump();
  service.completeCreate(CreateSuccess(session ?? fakeSession()));
  await tester.pumpAndSettle();
}
