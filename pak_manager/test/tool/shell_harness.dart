// Helper dùng chung cho test lớp shell của các cổng CI (story 1.15):
// tìm `bash`, quyết định bỏ qua/fail, dựng công cụ giả và chạy script với
// `PATH`/`ANDROID_HOME` tạm. Không dùng thư viện mock: công cụ giả là script
// bash đọc biến môi trường `PAK_FAKE_*`.

import 'dart:convert';
import 'dart:io';

/// Biến môi trường buộc test shell phải chạy (đặt ở job `android` của CI).
const requireShellTestsVar = 'PAK_REQUIRE_SHELL_TESTS';

/// Kết quả dò môi trường chạy test shell.
class ShellSupport {
  const ShellSupport({
    this.bash,
    this.unavailableReason,
    this.required = false,
  });

  /// Đường dẫn `bash`; null khi không chạy được test shell.
  final String? bash;

  /// Lý do không chạy được test shell; null khi chạy được.
  final String? unavailableReason;

  /// `PAK_REQUIRE_SHELL_TESTS=1`: không chạy được là fail, không bỏ qua.
  final bool required;

  bool get available => unavailableReason == null;

  /// Lý do bỏ qua để truyền vào `skip:`; null khi test phải chạy.
  String? get skipReason => unavailableReason;

  /// Thông báo fail khi bị yêu cầu chạy mà không chạy được; null nếu ổn.
  String? get failReason => required && !available
      ? '$requireShellTestsVar=1 nhưng không chạy được test shell: '
            '$unavailableReason'
      : null;
}

/// Tìm file thực thi [name] trên `PATH` của [environment].
String? findOnPath(String name, {Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final path = env['PATH'] ?? env['Path'] ?? '';
  final separator = Platform.isWindows ? ';' : ':';
  for (final dir in path.split(separator)) {
    if (dir.isEmpty) {
      continue;
    }
    final candidate = File('$dir/$name');
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }
  return null;
}

/// Quyết định chạy, bỏ qua hay fail test shell. Tham số chỉ để kiểm thử
/// chính hàm này.
ShellSupport detectShell({
  Map<String, String>? environment,
  bool? isWindows,
  String? Function(String name)? which,
}) {
  final env = environment ?? Platform.environment;
  final required = env[requireShellTestsVar] == '1';
  if (isWindows ?? Platform.isWindows) {
    // `bash` trên PATH có thể là WSL và công cụ giả dạng shebang không chạy
    // được: CI ubuntu là bằng chứng chính.
    return ShellSupport(
      unavailableReason: 'test shell không chạy trên Windows (CI ubuntu chạy)',
      required: required,
    );
  }
  final bash = (which ?? (n) => findOnPath(n, environment: env))('bash');
  if (bash == null) {
    return ShellSupport(
      unavailableReason: 'không tìm thấy bash trên PATH',
      required: required,
    );
  }
  return ShellSupport(bash: bash, required: required);
}

// Mọi công cụ giả ghi một dòng `<tên> <tham số…>` vào calls.txt.
const _logCall = r'echo "$(basename "$0") $*" >>"$PAK_FAKE_LOG/calls.txt"';

const _fakeAapt2 =
    '''
#!/usr/bin/env bash
# aapt2 giả: phát manifest.txt / badging.txt của thư mục fixture.
set -euo pipefail
$_logCall
case "\${1:-} \${2:-}" in
  "dump xmltree") cat "\$PAK_FAKE_FIXTURE/manifest.txt" ;;
  "dump badging") cat "\$PAK_FAKE_FIXTURE/badging.txt" ;;
  *) echo "aapt2 giả: tham số lạ: \$*" >&2; exit 64 ;;
esac
''';

const _fakeZipalign =
    '''
#!/usr/bin/env bash
# zipalign giả: phát zipalign.txt, exit theo PAK_FAKE_ZIPALIGN_EXIT.
set -euo pipefail
$_logCall
cat "\$PAK_FAKE_FIXTURE/zipalign.txt"
exit "\${PAK_FAKE_ZIPALIGN_EXIT:-0}"
''';

const _fakeUnzip =
    '''
#!/usr/bin/env bash
# unzip giả: `-l` phát listing.txt; `… 'lib/*' -d <dir>` tạo .so rỗng theo
# listing.
set -euo pipefail
$_logCall
if [[ "\${1:-}" == "-l" ]]; then
  cat "\$PAK_FAKE_FIXTURE/listing.txt"
  exit 0
fi
dest=""
while ((\$#)); do
  if [[ "\$1" == "-d" ]]; then
    dest="\${2:-}"
  fi
  shift
done
if [[ -z "\$dest" ]]; then
  echo "unzip giả: thiếu -d" >&2
  exit 64
fi
# Như unzip thật: không có file khớp 'lib/*' thì exit 11.
sos="\$(grep -oE 'lib/[^/ ]+/[^/ ]+\\.so\$' "\$PAK_FAKE_FIXTURE/listing.txt" || true)"
if [[ -z "\$sos" ]]; then
  exit 11
fi
while IFS= read -r so; do
  mkdir -p "\$dest/\$(dirname "\$so")"
  : >"\$dest/\$so"
done <<<"\$sos"
''';

const _fakeReadelf =
    '''
#!/usr/bin/env bash
# readelf giả: `-lW <…>/<abi>/<so>` phát readelf/<abi>/<so>.txt của fixture.
set -euo pipefail
$_logCall
so="\${*: -1}"
abi="\$(basename "\$(dirname "\$so")")"
cat "\$PAK_FAKE_FIXTURE/readelf/\$abi/\$(basename "\$so").txt"
''';

const _fakeDart = r'''
#!/usr/bin/env bash
# dart giả: ghi tham số và cây thư mục $work rồi gọi dart thật.
set -euo pipefail
printf '%s\n' "$@" >"$PAK_FAKE_LOG/dart_args.txt"
# Tham số: run tool/ci/apk_rules.dart <work> [applicationId]
if [[ -d "${3:-}" ]]; then
  (cd "$3" && find . -type f | LC_ALL=C sort) >"$PAK_FAKE_LOG/dart_work_tree.txt"
fi
exec "$PAK_REAL_DART" "$@"
''';

const _fakeGit = r'''
#!/usr/bin/env bash
# git giả: ghi tham số, in PAK_FAKE_GIT_REVISION, exit theo PAK_FAKE_GIT_EXIT.
set -euo pipefail
printf '%s\n' "$@" >"$PAK_FAKE_LOG/git_args.txt"
if [[ "${PAK_FAKE_GIT_EXIT:-0}" != "0" ]]; then
  echo "fatal: git giả lỗi" >&2
  exit "$PAK_FAKE_GIT_EXIT"
fi
echo "$PAK_FAKE_GIT_REVISION"
''';

/// Phiên bản build-tools giả mới nhất (script phải chọn bản này).
const fakeBuildToolsVersion = '36.1.0';

/// Thư mục tạm chứa công cụ giả, SDK Android giả và log lời gọi.
class FakeTools {
  FakeTools._(this.root);

  /// Tạo thư mục tạm cùng toàn bộ công cụ giả. Gọi [dispose] khi xong.
  factory FakeTools.create() {
    final tools = FakeTools._(Directory.systemTemp.createTempSync('pak_shell'));
    Directory(tools.log).createSync();
    // Bản cũ hơn, không có công cụ: `sort -V | tail -n 1` phải bỏ qua.
    Directory('${tools.sdk}/build-tools/34.0.0').createSync(recursive: true);
    final buildTools = '${tools.sdk}/build-tools/$fakeBuildToolsVersion';
    tools
      .._writeTool('$buildTools/aapt2', _fakeAapt2)
      .._writeTool('$buildTools/zipalign', _fakeZipalign)
      .._writeTool('${tools.bin}/unzip', _fakeUnzip)
      .._writeTool('${tools.bin}/readelf', _fakeReadelf)
      .._writeTool('${tools.bin}/dart', _fakeDart)
      .._writeTool('${tools.gitBin}/git', _fakeGit);
    File(tools.apk).writeAsStringSync('APK giả');
    return tools;
  }

  final Directory root;

  /// Thư mục đặt trước `PATH` (unzip, readelf, dart giả).
  String get bin => '${root.path}/bin';

  /// Thư mục chứa `git` giả, chỉ vào `PATH` khi `fakeGit: true`: wrapper
  /// `dart` của Flutter SDK tự gọi `git` nên không được che `git` thật khi
  /// script cần chạy `dart`.
  String get gitBin => '${root.path}/gitbin';

  /// `ANDROID_HOME` giả có `build-tools/<phiên bản>/{aapt2,zipalign}`.
  String get sdk => '${root.path}/sdk';

  /// Nơi công cụ giả ghi lời gọi.
  String get log => '${root.path}/log';

  /// File APK giả (script chỉ kiểm nó tồn tại).
  String get apk => '${root.path}/app.apk';

  void _writeTool(String path, String script) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(script.trimLeft());
    final chmod = Process.runSync('chmod', ['+x', path]);
    if (chmod.exitCode != 0) {
      throw StateError('chmod +x $path lỗi: ${chmod.stderr}');
    }
  }

  /// Nội dung file log [name], null nếu công cụ chưa được gọi.
  String? readLog(String name) {
    final file = File('$log/$name');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// Các dòng khác rỗng của file log [name] (rỗng nếu chưa có).
  List<String> logLines(String name) => [
    for (final line in (readLog(name) ?? '').split('\n'))
      if (line.isNotEmpty) line,
  ];

  /// Chạy `bash <script> <args…>` trong thư mục hiện tại (pak_manager/) với
  /// công cụ giả đứng trước `PATH` (`git` giả chỉ khi [fakeGit]). [environment] thêm biến `PAK_FAKE_*`.
  ProcessResult run(
    String bash,
    String script,
    List<String> args, {
    bool fakeGit = false,
    Map<String, String> environment = const {},
  }) {
    return Process.runSync(
      bash,
      [script, ...args],
      environment: {
        'PATH': [
          if (fakeGit) gitBin,
          bin,
          Platform.environment['PATH'] ?? '',
        ].join(':'),
        'ANDROID_HOME': sdk,
        'PAK_FAKE_LOG': log,
        ...environment,
      },
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  }

  void dispose() {
    root.deleteSync(recursive: true);
  }
}

/// Chép cả cây thư mục [from] sang [to] (giữ nguyên byte).
void copyTree(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(recursive: true)) {
    if (entity is File) {
      final rel = entity.path.substring(from.path.length + 1);
      File('${to.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}
