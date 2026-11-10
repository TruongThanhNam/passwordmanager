# `blocklist.bloom` — định dạng PAKB v1 (AD-15)

Sinh bằng `dart tool/blocklist/build_blocklist.dart` (trong `pak_manager/`).
Không sửa tay. Đọc bởi `BlocklistFilter.parse` (`lib/core/policy/`).

## Layout (little-endian)

| Offset | Kích thước | Trường | Giá trị |
|---|---|---|---|
| 0 | 4 | magic | `PAKB` |
| 4 | 1 | version (u8) | 1 |
| 5 | 1 | k (u8), số hàm băm | 10 |
| 6 | 2 | reserved (u16) | 0 |
| 8 | 4 | mBits (u32) | 9307763 |
| 12 | 4 | n (u32), số mục | 647380 |
| 16 | 4 | seed (u32) | `0x50414B31` ("PAK1") |
| 20 | ⌈mBits/8⌉ | bits | mảng bit |

Bit `i` nằm ở byte `20 + (i >> 3)`, bit `i & 7` (LSB trước).

## Tra cứu

`s` là byte ASCII của chuỗi đã chuyển chữ thường.

- `h1 = murmur3_x86_32(s, seed)`
- `h2 = murmur3_x86_32(s, seed ^ 0x9E3779B9) | 1`
- chỉ số thứ `j` (0 ≤ j < k) = `(h1 + j·h2) mod mBits`, tính bằng số nguyên
  64-bit (không tràn).

Chuỗi "có trong blocklist" khi cả `k` bit đều bật.

## Tham số

- Tỷ lệ dương tính giả thiết kế p = 0.001:
  `mBits = ⌈−n·ln p / (ln 2)²⌉`, k = 10.
- Tỷ lệ dương tính giả lý thuyết với n, mBits trên: 0.1000%.
- Kích thước file: 1163491 byte (trần 2097152).

## Nguồn

Repo `danielmiessler/SecLists`, commit `a1a06ab57c3f4efc450d80738a72c11597aac81a`, giấy phép MIT.
Chỉ giữ dòng ASCII in được (0x20–0x7E) dài 15–128
sau khi bỏ `\r` cuối dòng, chuyển chữ thường, khử trùng.

| File | Số dòng hợp lệ (trước khử trùng) |
|---|---|
| `Passwords/Common-Credentials/Pwdb_top-10000000.txt` | 124037 |
| `Passwords/Common-Credentials/xato-net-10-million-passwords.txt` | 141032 |
| `Passwords/Leaked-Databases/rockyou.txt.tar.gz` | 399299 |

Tổng sau khử trùng: 647380 mục.

Mẫu kiểm thử `test/fixtures/blocklist/sample.txt`: 500 mục, mục thứ
`i·⌊n/500⌋` của danh sách đã sắp xếp.
