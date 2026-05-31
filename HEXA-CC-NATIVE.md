@title: 🪆 HEXA-CC-NATIVE — "C 부산물 0 self-host"
@goal: hexa 가 자기 자신을 .c·.o·.a 어떤 C 중간물도 만들지 않고 native 백엔드(hexa codegen → machine-code → hexa_ld)만으로 처음부터 끝까지 재빌드하고, 그 native-built hexa 가 다시 자신을 재빌드해 byte-eq fixpoint 에 도달한다 (cross-arch: darwin-arm64 + linux-x86_64). C front(손-작성 .c)은 HEXA-CC-ZERO 가 이미 0 으로 닫음; 이 도메인은 BUILD front(빌드 중 생성되는 C 중간물)를 0 으로 닫는다.

# HEXA-CC-NATIVE — current state

HEXA-CC-ZERO 가 **커밋된 C**(트랜스파일러 씨앗 hexa_cc.c·cold-seed·native_gate.c)를 0 으로 만들었다. 그러나 빌드는 아직 `hexa → C → clang → .o → ar → .a → ld → 실행파일` 경로(C 백엔드)를 통과한다 — 즉 **빌드 도중 .c/.o/.a 가 생긴다**. 이 도메인은 그 마지막 C 의존을 없앤다: hexa 의 native 백엔드(자체 codegen + 자체 linker)만으로 컴파일러 자신을 self-host 하여, 빌드 산출물에 C 중간물이 0 이 되게 한다. CLAUDE.md `@I` 의 "no LLVM · no C-transpile" 정체성을 "지향"에서 "달성"으로 옮기는 트랙.

## 부품 인벤토리 (이미 repo 에 존재 — 재사용)

| 부품 | 파일 | 상태 |
|---|---|---|
| native codegen (asm emit) | `self/codegen/{arm64_darwin,x86_64_linux}.hexa` · `self/codegen.hexa` (`--emit=asm`) | ✅ 존재 |
| 실행파일 포맷 emit | `self/codegen/elf.hexa` (ELF64 · "no linker needed") + Mach-O | ✅ 존재 |
| 자체 링커 | `compiler/link/hexa_ld.hexa` v1.7 (ELF + Mach-O arm64 + ad-hoc 서명 + `--shared`) | ✅ 존재 |
| native 런타임 | `self/codegen/runtime_arm64.hexa` ("replaces runtime.c", raw ARM64 바이트) | ✅ 존재(arm64) |
| native build 드라이버 | `tool/build_hexac.hexa` (S4 native-path: `--emit=asm` → clang as+ld) | 🟠 S1-S4 |
| 결정성 검증 | `self/verify_native_determinism.hexa` | ⚠ scaffold(stub) |

## 현 frontier (정직)

- `tool/build_hexac.hexa` 가 native-path SSOT: S2 `aprime_cc --emit=asm` 로 **native codegen 까지는 C 없이** 도달. 그러나 **S4 가 clang 을 assembler+linker 로 shell** 하고 link 에 `runtime.c`(또는 release.yml Stage 0b 의 `runtime.a`)를 사용 → 여기서 C 중간물이 발생.
- 헤더 명시: "S7 (own assembler + `hexa_ld`) eliminates that last toolchain dependency" — S7 이 미완 = 이 도메인의 핵심 frontier.
- `.verdicts/`: `hexa-ld-*`(linker 단위 검증 다수 PASS) · `macho-*` · `verify-rebuild-identity7` · `unshadow-native-arr` 존재 → 부품 단위는 검증돼 있으나 **end-to-end C-free self-host fixpoint 는 미증명**.

## progress
- [x] N0 — frontier 측정 (baseline) · native-path 가 .c/.o/.a 를 어디서 만드는지 1회 실측: build_hexac.hexa S1-S4 를 darwin-arm64 에서 돌려 각 stage 산출물 종류 + clang/ar/ld 호출 지점 + runtime.c|.a 참조를 verdict 로 캡처 (현 C-중간물 inventory) · 🟢 N0 MEASURED(2026-05-31): native `--emit=obj --backend=native` 가 이미 C-free + 0-fork(.o 직접 emit · F-P3-ZERO-EXTERN + F-P0-OBJEQ corpus PROVEN). 잔여 frontier = **exec-link** 만 (hexa_ld 가 runtime.o+crt 미링크 = `--emit=exec` gap). shipping build_hexac 는 아직 --emit=asm+clang. verdict: `.verdicts/hexa-cc-native/F-HEXA-CC-NATIVE-N0-FRONTIER.txt`
- [ ] N1 — native runtime: linux-x86_64 런타임 바이트 (runtime_arm64.hexa 대응 x86_64 버전) 완성 · arm64 는 존재, x86_64 emit 경로 PASS (syscall write/exit/mmap raw bytes) verdict
- [ ] N2 — 자체 assembler (S7-as): clang assemble 단계 제거 — native codegen 이 .s(asm text) 대신 object/machine-code 바이트를 직접 emit (elf.hexa/macho 경로로) → clang -c 불요. 단일 모듈 round-trip PASS · ⚠ N0 재평가: native obj-emit 가 .s/as 경로를 우회하므로 self-assembler 는 대체로 MOOT — asm fallback 용으로만 보류 (N0 verdict 참조)
- [ ] N3 — hexa_ld 링크 배선 (S7-ld): clang link 단계 제거 — hexa_ld.hexa 로 native object → 실행파일 링크. build_hexac S4 를 self-as + hexa_ld 로 교체, clang 호출 0. ./hexac --version PASS (darwin-arm64) · 🔬 N3-SMOKE(2026-05-31): exec-link frontier = 정확히 2개 배선 — (N3a) native runtime `.o` 가 `_hexa_exit`/`_hexa_set_args` export 안 함 + (N3b) `--emit=exec` 가 hexa_ld 대신 system `ld` fork. 링커 자체는 PROVEN(P1_LINKEXEC: 2 .o→실행 exit42, clang/ld 0). build/aprime_cc 직접 측정(설치 hexa 는 stale-codegen 버그로 우회). verdict: `.verdicts/hexa-cc-native/F-HEXA-CC-NATIVE-N3-SMOKE.txt`
- [ ] N4 — C-중간물 0 확인: native-path full build 산출물 트리에서 .c/.o/.a 파일 0 개 (find 검증) · runtime.c/.a 미참조 · clang/gcc/ar/ld 외부 호출 0 (strace/exec-trace) verdict
- [ ] N5 — self-host fixpoint (byte-eq): native-built hexac 가 자기 SSOT 를 재컴파일(gen2) → 그 gen2 가 다시 재컴파일(gen3) → gen2≡gen3 실행파일 byte-eq (per-arch deterministic) darwin-arm64
- [ ] N6 — cross-arch: N2-N5 를 linux-x86_64 에서도 PASS (native as+ld+runtime+fixpoint). per-arch byte-eq (cross-arch strict byte-eq 는 codegen arch-specific 이라 비요구, P1/P3 모델 일치)
- [ ] N7 — CI 게이트: native C-free self-host 를 nobaseline-gate 류 워크플로로 승격 (3-platform) — `.c/.o/.a=0` 산출물 assert + fixpoint assert green. release 무손상(병렬 옵션, green 될 때까지 C 경로 유지)
