# Fixture vault v1 (AD-20)

Sinh bằng `dart run tool/fixtures/gen_vault_v1.dart` (trong `pak_manager/`).
Không sửa tay: CI chạy lại script và đòi `git status` sạch. Mọi dữ liệu là giả.

Script không import `lib/` của app; nó tự ghép byte theo AD-20 để golden test
(`test/core/format/`) bắt được lỗi của `HeaderCodec`/`VaultFileCodec`.

## Đầu vào cố định

| Trường | Giá trị |
|---|---|
| Mật khẩu (ASCII) | `fixture-only correct horse 42` |
| KDF | Argon2id13, opslimit 2, memlimit 19922944 byte (19 MiB), p=1, KEK 32 byte |
| DEK | `000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f` |
| salt | `202122232425262728292a2b2c2d2e2f` |
| wrapNonce (header) | `404142434445464748494a4b4c4d4e4f5051525354555657` |
| nonce `cards` | `606162636465666768696a6b6c6d6e6f7071727374757677` |
| nonce `recent` | `808182838485868788898a8b8c8d8e8f9091929394959697` |

## Bản rõ

`cards` (AD `PAK-VAULT/cards/v1`):

```json
{"v":1,"cards":[{"id":"3f2b8c1e-5d4a-4e6f-9a7b-1c2d3e4f5a6b","title":"Example Mail","username":"alice@example.com","password":"Fake-Pass-0001!","note":"","createdAt":1762300800000},{"id":"a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d","title":"Ngân hàng giả","username":"nguyen.van.a","password":"p@ss word ~ demo","note":"Ghi chú: dữ liệu giả, không dùng thật.","createdAt":1762387200000}]}
```

`recent` (AD `PAK-VAULT/recent/v1`):

```json
{"v":1,"items":[{"password":"K9#mVq2!xLp7wZr","recordedAt":1762390800000}]}
```

## File

- `header`: 155 byte, layout AD-20 little-endian; AD bọc DEK = byte [0,35);
  `kcv` = BLAKE2b-16 khóa KEK trên `PAK-KCV-v1`; `checksum` = BLAKE2b-256 trên
  [0,123).
- `cards`, `recent`: `nonce[24] ‖ ciphertext‖tag`, XChaCha20-Poly1305 bằng DEK.
