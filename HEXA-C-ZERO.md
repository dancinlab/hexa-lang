@title: 🔥 HEXA-C-ZERO — "C 완전 박멸"
@goal: repo 전체 .c = 0 (literal none-cc none-c). 트랜스파일러 씨앗 + 손-작성 shim + generated runtime.c + GPU .cu/.metal/.m 까지 — hexa가 C를 한 줄도 생성·커밋하지 않고 native backend(기계어 직접 emit)로 자기를 빌드.

# HEXA-C-ZERO — current state

기준 = **none cc, none c** (literal). HEXA-CC-ZERO(트랜스파일러 씨앗)는 이 도메인의 첫 마일스톤으로 흡수.

## 인벤토리 (origin/main 실측 2026-05-30)

| tier | 대상 | 개수 | 전략 |
|---|---|---|---|
| A. committed .c | hexa_cc_seed·native_gate·m7-probe×2 | 4 | 제거/포팅 (즉시) |
| B. committed .cu/.metal/.m | GPU·Metal·ObjC | 124 (93·22·9) | hexa GPU codegen 포팅 (다년) |
| C. generated .c | runtime.c 등 emitter-SSOT | 52 | native backend default flip |

★ native backend 이미 존재: `self/codegen/ir_to_arm64.hexa`·`ir_to_x86.hexa`·`elf.hexa` (C 안 거치고 기계어 직접). tier C는 이 backend를 default로 flip하면 C 미생성 → 소멸.

## progress

- [ ] C1 — committed transpiler .c = 0 (`hexa_cc_seed.c` git rm + warm-seed 복귀) — **git-rm 반쪽 CLOSED · warm-CI 반쪽 DEFERRED (honest)**. cold-seed `hexa_cc_seed.c` origin/main 에서 부재 확인(`.verdicts/hexa-c-zero/C1-GROUND-TRUTH.txt`) → 커밋된 트랜스파일러 .c = 0. warm-install CI(`hx install` → `hexa cc --regen` → build → smoke)는 **upstream 2중 RED 으로 미달**: ① edge release 에 `hexa-linux-x86_64.tar.gz` 부재(release.yml x86_64 long-red) ② `hexa cc --regen` clean-main self-host 깨짐(handoff 726b8b67·e311289a). → `bootstrap.yml` DISABLED stub 유지(no fake green) · 블로커 문서화(`.verdicts/hexa-c-zero/C1-WARM-SEED-CI.txt`). 두 upstream RED 해소 시 warm-CI green 으로 C1 flip.
- [ ] C2 — m7-probe 2 .c → .hexa 포팅 (or rm) → committed probe .c = 0
- [ ] C3 — `native_gate.c` → emit-SSOT 포팅 (committed 0) → 이후 native obj emission으로 generated도 0
- [ ] C4 — **keystone**: native backend(ir_to_arm64/x86+elf) HEXA_BACKEND default flip → generated C 52개 미생성
- [ ] C5 — runtime floor (runtime.c/runtime_core.c) hexa-native (RUNTIME.md phase H)
- [ ] C6 — GPU/Metal/ObjC 124 (.cu/.metal/.m) → hexa GPU codegen 포팅 (다년 arc)
- [ ] C7 — 최종 검증: `git ls-tree` + 빌드산출 전수 .c=0, native backend로 fresh build green

## honest note
1사이클로 literal 0 불가 — A tier(4)는 즉시, B(124)·C(52)는 multi-cycle keystone(native flip)+다년 GPU arc. HEXA-CC-ZERO의 P3/P5/P6 cold-seed/seed-refresh 는 option2 사용자 결정으로 **SUPERSEDED**(커밋 .c 0 우선) — `hexa_cc_seed.c` git rm 완료. warm-seed bootstrap 만 지원(bare-clone cold-boot 능력은 의도적 포기). C1 warm-CI green 은 release-pipeline + `hexa cc --regen` 두 upstream RED 가 막고 있어 deferred(honest, fake green 금지).
