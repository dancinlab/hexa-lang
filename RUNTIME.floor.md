# 🧱 RUNTIME.floor — 물리 바닥 레인 (hexa-native frontier)

> Sibling to `RUNTIME.flip.md` (quick-win lane). This file owns the
> physical-floor analysis: what stays as a thin FFI/asm interface.

## @goal

runtime FLOOR (repr/arena/GC + vendor FFI + kernel syscall) 의
hexa-native frontier 를 추적. 물리 한계(roofline)까지 도달.

## 현 상태 (2026-05-28)

| axis | 값 |
|---|---|
| repr/arena/GC | ~240 fn FLOOR |
| vendor FFI | ③19 (CUDA/openssl/sodium) |
| kernel syscall | inline svc · 0 externs |
| boot vector | `.s` boot-floor |

## floor 클래스

1. **GC/repr/arena FLOOR** — ~240 fn, bootstrap seed (phase-H lane).
   HexaVal 자기참조 repr · arena alloc · GC mark/sweep.
2. **kernel syscall** — svc #0x80 (inline · 0 externs).
3. **vendor FFI** — CUDA/openssl/sodium/OS-ABI. FFI 가 correct terminal interface.

## F1 — repr/arena/GC FLOOR

HexaVal repr core · arena · GC = bootstrap seed. self-hosting 컴파일러는
SOME machine-code seed 가 phase-H lane 에서 codegen self-emit 로 닫힌다.

## F2 — perf-kernel floor

hxflash/hxlayer/hxvdsp = `@link` FFI `.so` (H100 배포 · 285x). pure-hexa
등가 존재하나 측정상 285x 느림 → perf-floor (벤더 핫패스 유지).

## F3 — hexa_cc boot-image lane

`self/native/hexa_cc` boot-image = hexa_v2 첫 빌드 seed. prior hexa
`hexa cc --regen` 로 hexa-native 재생성 (RUNTIME.floor F3 runbook).

## F-residual

- vendor FFI ③19 (CUDA/openssl/sodium/OS-ABI) — 영구 FFI interface

## F1 detail — repr/arena/GC

HexaVal 자기참조 · Robin Hood intern · arena grow. 이 LOGIC 이
codegen self-emit 로 hexa-native 가능 — phase-H lane.

## 측정 (perf-floor)

hxlayer C 285x vs pure-hexa. ML 학습 hot-path → 벤더 핫패스 유지.

## F3 — hexa_cc 활성화 runbook

hexa_cc boot-image = bootstrap floor (phase-H lane). codegen self-emit
가 닫는 잔여.

## bootstrap 경로

부트스트랩 = edge tarball 의 prebuilt `build/runtime.a` + `build/hexat` 를
`tool/release_build` → `tool/release_package` 단일 진입점이 링크. prior hexa
`hexa cc --regen` 로 boot-image 를 hexa-native 재생성 (mechanism PROVEN —
18/18 byte-identical).

## boot vector

boot-floor (`.s`) = vector-table · RFC 063/064 lowering lane.

## vendor FFI 영구 floor

CUDA/openssl/sodium/OS-ABI = vendor ABI interface. FFI 가 correct
terminal state (벤더 커널모드 드라이버 재구현 불가 — 물리 한계).

## perf-floor 측정

hxflash/hxlayer/hxvdsp = @link FFI .so. C 285x vs pure-hexa.
벤더 핫패스 유지. perf-floor.

## handoff cross-ref

[B-갈래 handoff items]
