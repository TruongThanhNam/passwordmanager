import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/io/tmp_sweeper.dart';

void main() {
  late Directory sandbox;
  late String pak;
  final sep = Platform.pathSeparator;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('pak_sweep_');
    pak = '${sandbox.path}${sep}pak';
    Directory('$pak${sep}vault').createSync(recursive: true);
  });

  tearDown(() {
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  File file(String rel, [List<int> bytes = const [1]]) =>
      File('$pak$sep${rel.replaceAll('/', sep)}')..writeAsBytesSync(bytes);

  test('nfr11_sweep_deletes_tmp_at_every_level_keeps_other_files', () async {
    final rootTmp = file('a.tmp');
    final vaultTmp = file('vault/cards.tmp');
    final cards = file('vault/cards', [4, 2]);
    final header = file('vault/header');
    final settings = file('settings');

    final deleted = await sweepTmpFiles(pak);

    expect(deleted, 2);
    expect(rootTmp.existsSync(), isFalse);
    expect(vaultTmp.existsSync(), isFalse);
    expect(cards.readAsBytesSync(), [4, 2]);
    expect(header.existsSync(), isTrue);
    expect(settings.existsSync(), isTrue);
  });

  test('nfr11_sweep_reaches_nested_directories', () async {
    Directory('$pak${sep}tmp${sep}x').createSync(recursive: true);
    final nested = file('tmp/x/export.tmp');

    expect(await sweepTmpFiles(pak), 1);
    expect(nested.existsSync(), isFalse);
    expect(Directory('$pak${sep}tmp${sep}x').existsSync(), isTrue);
  });

  test('nfr11_sweep_only_matches_tmp_suffix', () async {
    final keep = [file('vault/tmp'), file('vault/cards.tmp.bak'), file('tmpx')];

    expect(await sweepTmpFiles(pak), 0);
    for (final f in keep) {
      expect(f.existsSync(), isTrue);
    }
  });

  test('nfr11_sweep_missing_dir_returns_zero_without_throwing', () async {
    expect(await sweepTmpFiles('${sandbox.path}${sep}missing'), 0);
  });

  test(
    'nfr11_sweep_does_not_follow_symlinks',
    () async {
      final outside = Directory('${sandbox.path}${sep}outside')..createSync();
      final outsideTmp = File('${outside.path}${sep}keep.tmp')
        ..writeAsBytesSync([1]);
      Link('$pak${sep}link').createSync(outside.path);

      expect(await sweepTmpFiles(pak), 0);
      expect(outsideTmp.existsSync(), isTrue);
    },
    // Tạo symlink trên Windows cần quyền Developer Mode.
    skip: Platform.isWindows ? 'symlink cần quyền trên Windows' : false,
  );

  test('nfr11_delete_failure_does_not_stop_other_files', () async {
    final locked = file('vault/locked.tmp');
    final other = file('a.tmp');
    final lockedDir = Directory('$pak${sep}vault');
    RandomAccessFile? handle;
    if (Platform.isWindows) {
      // Windows không xóa được file đang mở.
      handle = locked.openSync(mode: FileMode.append);
    } else {
      // POSIX: thư mục chỉ đọc thì không xóa được file bên trong.
      Process.runSync('chmod', ['555', lockedDir.path]);
    }
    try {
      expect(await sweepTmpFiles(pak), 1);
      expect(other.existsSync(), isFalse);
      expect(locked.existsSync(), isTrue);
    } finally {
      handle?.closeSync();
      if (!Platform.isWindows) {
        Process.runSync('chmod', ['755', lockedDir.path]);
      }
    }
  });

  test('nfr11_directory_named_tmp_is_traversed_not_deleted', () async {
    Directory('$pak${sep}dir.tmp').createSync();
    final a = file('dir.tmp/inner.tmp');
    final b = file('vault/b.tmp');

    expect(await sweepTmpFiles(pak), 2);
    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isFalse);
    expect(Directory('$pak${sep}dir.tmp').existsSync(), isTrue);
  });
}
