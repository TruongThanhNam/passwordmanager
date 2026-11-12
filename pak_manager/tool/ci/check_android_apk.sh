#!/usr/bin/env bash
# Kiểm APK release (AD-11, AD-12, AD-15, AD-19). Script chỉ gọi công cụ và lưu
# output thô vào thư mục làm việc; luật nằm ở tool/ci/apk_rules.dart (có test
# kiểm âm trong test/tool/apk_rules_test.dart).
#   - zipalign -c -P 16: mọi .so không nén được căn 16 KB trong APK.
#   - apk_rules.dart: manifest (INTERNET, backup), listing (ABI, libsodium,
#     blocklist), readelf (LOAD >= 0x4000 với ABI 64-bit), badging (applicationId).
#
# Dùng (trong pak_manager/):
#   tool/ci/check_android_apk.sh <đường-dẫn-apk> [--expect-id <applicationId>]
# Cần: ANDROID_HOME (hoặc ANDROID_SDK_ROOT) có build-tools (aapt2, zipalign),
#      readelf, unzip, dart.
set -euo pipefail

apk="${1:?Dùng: check_android_apk.sh <apk> [--expect-id <id>]}"
shift
expect_id=""
while (($#)); do
  case "$1" in
    --expect-id)
      expect_id="${2:?--expect-id cần applicationId}"
      shift 2
      ;;
    *)
      echo "Tham số không hợp lệ: $1" >&2
      exit 1
      ;;
  esac
done
if [[ ! -f "$apk" ]]; then
  echo "Không tìm thấy APK: $apk" >&2
  exit 1
fi

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$sdk" || ! -d "$sdk/build-tools" ]]; then
  echo "ANDROID_HOME/ANDROID_SDK_ROOT chưa đặt hoặc thiếu build-tools" >&2
  exit 1
fi
build_tools="$(find "$sdk/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
aapt2="$build_tools/aapt2"
zipalign="$build_tools/zipalign"
for tool in "$aapt2" "$zipalign"; do
  [[ -x "$tool" ]] || { echo "Thiếu $tool" >&2; exit 1; }
done
for tool in readelf unzip dart; do
  command -v "$tool" >/dev/null || { echo "Thiếu $tool" >&2; exit 1; }
done
echo "APK: $apk"
echo "build-tools: $build_tools"

failed=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo
echo "== zipalign 16 KB (AD-19)"
if "$zipalign" -c -P 16 -v 4 "$apk" >"$work/zipalign.txt" 2>&1; then
  grep -E '\.so ' "$work/zipalign.txt" || true
  echo "OK: zipalign -c -P 16 -v 4"
else
  grep -E '\.so |BAD|fail' "$work/zipalign.txt" || cat "$work/zipalign.txt"
  echo "FAIL: zipalign -c -P 16 -v 4"
  failed=1
fi

echo
echo "== Thu thập output aapt2/unzip/readelf"
"$aapt2" dump xmltree --file AndroidManifest.xml "$apk" >"$work/manifest.txt"
unzip -l "$apk" >"$work/listing.txt"
unzip -q -o "$apk" 'lib/*' -d "$work/apk" || true
shopt -s nullglob
for so in "$work"/apk/lib/*/*.so; do
  rel="${so#"$work/apk/lib/"}"
  mkdir -p "$work/readelf/$(dirname "$rel")"
  readelf -lW "$so" >"$work/readelf/$rel.txt"
done
rule_args=("$work")
if [[ -n "$expect_id" ]]; then
  "$aapt2" dump badging "$apk" >"$work/badging.txt"
  rule_args+=("$expect_id")
fi

echo
echo "== Luật APK (tool/ci/apk_rules.dart)"
if dart run tool/ci/apk_rules.dart "${rule_args[@]}"; then
  echo "OK: apk_rules"
else
  echo "FAIL: apk_rules"
  failed=1
fi

echo
if ((failed)); then
  echo "check_android_apk: FAIL"
  exit 1
fi
echo "check_android_apk: OK"
