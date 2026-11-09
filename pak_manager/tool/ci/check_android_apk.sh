#!/usr/bin/env bash
# Kiểm APK release (AD-12, AD-19):
#   1. Manifest đã merge không có android.permission.INTERNET; có
#      allowBackup=false, dataExtractionRules và fullBackupContent (AD-11).
#   2. zipalign: mọi .so không nén được căn 16 KB trong APK.
#   3. readelf: mọi segment LOAD của lib/*/*.so có Align >= 0x4000 (16 KB);
#      APK phải có lib/arm64-v8a/, và mọi lib/<abi>/ phải có libsodium.so.
#
# Dùng: tool/ci/check_android_apk.sh <đường-dẫn-apk>
# Cần: ANDROID_HOME (hoặc ANDROID_SDK_ROOT) có build-tools (aapt2, zipalign),
#      readelf, unzip.
set -euo pipefail

apk="${1:?Dùng: check_android_apk.sh <apk>}"
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
for tool in readelf unzip; do
  command -v "$tool" >/dev/null || { echo "Thiếu $tool" >&2; exit 1; }
done
echo "APK: $apk"
echo "build-tools: $build_tools"

failed=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo
echo "== Quyền INTERNET (AD-12)"
"$aapt2" dump xmltree --file AndroidManifest.xml "$apk" >"$work/manifest.txt"
if grep -q 'android.permission.INTERNET' "$work/manifest.txt"; then
  echo "FAIL: manifest có android.permission.INTERNET"
  grep -n -B2 'android.permission.INTERNET' "$work/manifest.txt" || true
  failed=1
else
  echo "OK: manifest không có android.permission.INTERNET"
fi

echo
echo "== Loại khỏi backup (AD-11, NFR-8)"
# aapt2 in thuộc tính dạng `A: http://schemas.android.com/apk/res/android:allowBackup(0x01010280)=false`;
# boolean đôi khi in dạng `(type 0x12)0x0`.
if grep -qE ':allowBackup\(0x[0-9a-fA-F]+\)=(false|\(type 0x12\)0x0)([[:space:]]|$)' "$work/manifest.txt"; then
  echo "OK: android:allowBackup=false"
else
  echo "FAIL: manifest không có android:allowBackup=false"
  grep -n 'allowBackup' "$work/manifest.txt" || true
  failed=1
fi
for attr in dataExtractionRules fullBackupContent; do
  if grep -qE ":$attr\(0x[0-9a-fA-F]+\)=@" "$work/manifest.txt"; then
    echo "OK: android:$attr trỏ tới resource"
  else
    echo "FAIL: manifest thiếu android:$attr"
    failed=1
  fi
done

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
echo "== Căn ELF LOAD >= 0x4000 (AD-19)"
unzip -q -o "$apk" 'lib/*' -d "$work/apk" || true
shopt -s nullglob
libs=("$work"/apk/lib/*/*.so)
if ((${#libs[@]} == 0)); then
  echo "FAIL: APK không có lib/*/*.so"
  failed=1
fi
# Build hook của sodium đặt tên asset theo libraryFileName('sodium'). APK
# release là bản fat: mọi ABI có .so đều phải có libsodium.so.
if [[ ! -d "$work/apk/lib/arm64-v8a" ]]; then
  echo "FAIL: APK thiếu lib/arm64-v8a/"
  failed=1
fi
for abi_dir in "$work"/apk/lib/*/; do
  abi="$(basename "$abi_dir")"
  if [[ -f "$abi_dir/libsodium.so" ]]; then
    echo "OK: APK có lib/$abi/libsodium.so"
  else
    echo "FAIL: APK thiếu lib/$abi/libsodium.so (build hook của sodium không chạy?)"
    failed=1
  fi
done
for so in "${libs[@]}"; do
  rel="${so#"$work/apk/"}"
  aligns="$(readelf -lW "$so" | awk '$1 == "LOAD" { print $NF }')"
  if [[ -z "$aligns" ]]; then
    echo "FAIL: $rel không có segment LOAD"
    failed=1
    continue
  fi
  bad=""
  for align in $aligns; do
    if ((align < 0x4000)); then
      bad="$bad $align"
    fi
  done
  if [[ -n "$bad" ]]; then
    echo "FAIL: $rel có LOAD align <0x4000:$bad"
    failed=1
  else
    echo "OK: $rel (align: $(echo "$aligns" | sort -u | tr '\n' ' '))"
  fi
done

echo
if ((failed)); then
  echo "check_android_apk: FAIL"
  exit 1
fi
echo "check_android_apk: OK"
