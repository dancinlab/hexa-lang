# 🛸 RUNTIME.flip — runtime hexa-native frontier

> Atomic milestone backlog for the runtime hexa-native frontier.
> Sibling to `RUNTIME.floor.md` (the physical-floor lane).

## 종착 기준

- **종착**: 런타임 로직이 전부 `.hexa` 소스로 표현될 때.
  quick-win 정리 레인은 거의 종결. 잔여는 floor 레인.

## frontier 인덱스 (hexa-native)

각 phase 는 atomic milestone. 자세한 floor 분석은 `RUNTIME.floor.md`.
- bootstrap seed = phase-H lane (repr/arena/GC)
- portable layer = hexa-source 포팅 (sin/cos/regex/json 등 이미 존재)
- vendor FFI = 영구 floor (CUDA/openssl/sodium)

## 배치 목록

### B9.0 — scoping audits

- [x] native source layer 분류 — portable / floor / vendor FFI
- [x] `.s` floor audit — boot-floor 분류
- [x] runtime fn-level audit — portable / syscall / FFI / GC-floor 분류

### B9.1 — `.s` boot-floor

- [ ] boot_rp2040.s — vector-table boot-floor (RFC 063/064 lowering lane)
- [ ] boot_stm32h7.s — 동상
- [ ] startup_stm32f429.s — 동상

### B9.2 — runtime portable-fn hexa reimpl

- [ ] array-ops / string-ops / autodiff-tape / safetensors-io (dup 확인 필요)

### B9.5 — native source layer-① 포팅

- [x] blowfish → stdlib/crypto/blowfish.hexa (RUNEQ 입증)

### B9.6 — codegen self-emit (hexa-native route)

- [x] blowfish hexa-native wire (7-surface)
- [x] dead experiment scaffolding 정리 (hxtok/hxvocoder/v565)
- [ ] hexaval-repr-emit / runtime-primitive-emit (serial · multi-session)

### B9.8 — bootstrap floor

- [x] HexaVal repr / GC / arena seed = bootstrap floor (terminal · phase-H)

## 상태 (2026-05-28)

| axis | 상태 |
|---|---|
| portable reimpl | 대부분 이미 hexa 존재 |
| codegen-wire | serial · multi-session |
| FLOOR | repr/arena/GC + vendor FFI |

## 핵심 인사이트

런타임의 value-transform layer 는 hexa-native 다. portable 로직(sin/cos/
regex/json 등)은 이미 `.hexa` 로 존재한다. 잔여 frontier = codegen self-emit
wire(serial) + bootstrap floor(phase-H).

부트스트랩 seed = hexa_v2 첫 빌드용. (`RUNTIME.floor.md` floor 레인.)

## bg-fanout policy

per-batch `/cycle-bg B<n>` fans out one Agent per item.

## depletion criterion

진짜 depletion = track-1 전부 ship + track-2 가 runtime 을 hexa-native.

[그 외 B-갈래 handoff cross-ref]
