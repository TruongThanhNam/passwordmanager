#!/usr/bin/env bash
# So revision của bản Flutter đã clone với revision ghi trong .metadata
# (AD-12, AD-18): tag Flutter có thể bị dời nên không tin tên tag.
# Một nguồn duy nhất cho cả bốn job CI; kiểm âm ở
# test/tool/check_flutter_revision_sh_test.dart.
#
# Dùng (trong pak_manager/):
#   tool/ci/check_flutter_revision.sh <thư-mục-flutter> [file-metadata=.metadata]
# Cần: git, grep.
set -euo pipefail

flutter_dir="${1:?Dùng: check_flutter_revision.sh <thư-mục-flutter> [file-metadata]}"
metadata="${2:-.metadata}"
if [[ ! -f "$metadata" ]]; then
  echo "Không tìm thấy file metadata: $metadata" >&2
  exit 1
fi

# Dòng `  revision:` (thụt 2 dấu cách) là revision Flutter; các dòng
# `create_revision`/`base_revision` thụt sâu hơn nên không khớp.
expected="$(grep -m1 -E '^  revision:' "$metadata" | grep -oE '[0-9a-f]{40}' || true)"
actual="$(git -C "$flutter_dir" rev-parse HEAD)" || {
  echo "Không đọc được revision của Flutter clone: $flutter_dir" >&2
  exit 1
}
if [[ -z "$expected" || "$actual" != "$expected" ]]; then
  echo "Flutter clone có revision $actual, khác revision '$expected' trong $metadata" >&2
  exit 1
fi
echo "OK: Flutter revision $actual khớp $metadata"
