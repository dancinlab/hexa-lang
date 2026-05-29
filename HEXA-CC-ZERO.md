@title: 🌱 HEXA-CC-ZERO — "마지막 C 씨앗 제거"
@goal: self/native/hexa_cc.c 를 repo에서 완전히 제거한다 — `hexa cc --regen` 이 4개 .hexa SSOT 모듈에서 트랜스파일러를 warm-rebuild 하게 하여, 손으로 유지하던 마지막 C 시드를 없애고 "0 .c" self-host에 도달한다.

# HEXA-CC-ZERO — current state

손-유지 C는 사실상 `self/native/hexa_cc.c`(트랜스파일러 씨앗) 하나만 남았다. 이걸 없애면 컴파일러가 자기 자신을 자기 언어로만 다시 만든다.

## progress

- [ ] P1 — `hexa cc --regen` fixpoint byte-eq (재생성 트랜스파일러 == 기존 트랜스파일러) · 🟡 PARTIAL: Mac arm64 self-host fixpoint(v_n≡v_{n+1}) 4/4 byte-eq 실측 PASS — 단 in-tree seed 가 stale(자기 SSOT 의 fixpoint 아님) + ubu x86_64 cross-host 잔여
- [ ] P2 — cross-host kill-storm-free (Mac arm64 + ubu x86_64 둘 다 warm-rebuild PASS)
- [ ] P3 — stage-(-1) seed 전략 (hexa_cc.c 없이 cold bootstrap 경로 확정)
- [ ] P5 — `--prefer-regen` opt-in flag 활성 (build_hexa_cli.hexa step 0)
- [ ] P6 — `self/native/hexa_cc.c` git rm + CI/fresh-clone green

## 2026-05-30 P1 PROBE 측정 (verdict 첨부)

verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-PROBE.txt` (양 호스트 stdout verbatim)

측정 결과 (read-only `--probe`, heavy regen 미실행 — Mac kill-storm gate 준수):

- 🟢 **파일 제거(구 P6)는 사실상 완료** — `self/native/hexa_cc.c` 는 Mac·ubu-2 fresh clone 모두에서 untracked + `.gitignore` L286 + `origin/main` MISSING. 단 `git rm` 형식 종결/CI green 은 미검증이라 P6 체크박스는 보류.
- 🔴 **P1 byte-eq fixpoint 는 이번 사이클 미측정** — `cc --regen` 은 Mac kill 게이트, ubu-2 fresh clone 은 probe 바이너리 링크에 runtime amalgam(runtime.c/runtime_core.c/forge_tier_v1.c — 모두 gitignored generated) 전체 빌드가 필요. runbook 의 "P1 PROVEN @ d1994dfea(#1533)" 는 citation 이지 이번 verdict 아님. 실측은 build-capable 호스트(`pool on mini` / `LOCAL_BUILD=1` / ubu-2 full build)에서 `--byte-eq` 1회 필요.
- 🔴 **진짜 잔여 frontier = cold-bootstrap 의존성 (P3)** — `tool/build_hexa_cli.hexa:612-618` 와 `self/main.hexa:1337(cmd_cc)` 둘 다 gitignored·fresh-clone-absent 인 `hexa_cc.c` 를 hard-require. host 에 hexa/hexa-run 이 미설치된 진짜 fresh clone 은 `build/hexat` 부트스트랩 불가 → 현 상태는 WARM-seed(host hexa 가 먼저 `cc --regen` 으로 hexa_cc.c 재생성) bootstrap 이지 true stage-(-1) cold seed 아님.
- ℹ️ plan 전제 "self/native/hexa_v2 = git-tracked binary seed" 는 FALSIFIED — hexa_v2 는 gitignored(L138, CANON M3b "트랜스파일러 바이너리는 git 에 없음"). git-tracked artifact 는 1052 B `hexa_cc.c.hexanoport`(marker doc, 컴파일 불가) 뿐.

## 2026-05-30 P1 BYTE-EQ 실측 (Mac arm64 · verdict 첨부)

verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-BYTEEQ-MAC.txt` (mini stdout + per-module md5 verbatim)

prior PROBE(#2103)는 read-only 라 P1 byte-eq 를 측정 못했음. 이번 사이클은 `pool on mini` 에서 **실제 warm-rebuild** (`hexa cc --regen`, HEAVY, HEXA_MEM_UNLIMITED=1) 1회 실행 + 2-iteration fixpoint(v_n==v_{n+1}) 측정. 설치 hexa.real·in-tree hexa_cc.c 미변경 (build/hexat 는 mini-local untracked artifact, swap 후 backup md5 검증 복원).

- 🟢 **self-host fixpoint v_n ≡ v_{n+1} = 4/4 모듈 BYTE-EQ (Mac arm64)** — hexat.new 로 SSOT 재트랜스파일(gen2) → hexat.new2 로 재트랜스파일(gen-N+1) → lexer/parser/type_checker/codegen 출력 .c 가 모두 byte-identical (md5 일치). regen 결정성(gen2==gen3)도 PASS. **트랜스파일러가 자기 SSOT 로부터 자기 자신을 안정적으로 재생산함 = P1 의 핵심 성질 입증.**
- 🔴 **단, 커밋된 in-tree seed(af645e419)는 자기 SSOT 의 fixpoint 가 아님 (stale)** — `git`커밋된 build/hexat·hexa_cc.c 로 만든 출력(gen1) vs 현 SSOT 출력(gen2)은 153 hunk DRIFT. 원인: (1) main 템플릿 setvbuf emit 추가, (2) parser 신규 string-lit "shared"/",shared" sl 슬롯 +2 renumber, (3) codegen comptime const-fold(max_scan→64, _strlit_chunk→500). 셋 다 SSOT 가 NEWER = 최종 regen 없이 커밋된 seed. → seed 갱신(재regen+커밋) 필요.
- ⏸ **ubu x86_64 cross-host 는 미측정** — sibling agent(linux-hexat-trim-fix) 점유로 이번 사이클 OFF-LIMITS. P2(cross-host) 와 함께 deferred follow-up.
- 🟡 **결론**: P1 은 Mac arm64 self-host fixpoint 성질만 PASS = **PARTIAL**. fully-closed 아님 (seed 갱신 + ubu cross-host 2건 잔여). 표기 정정: byte-eq 기준은 트랜스파일러 *출력*(.c) 의 byte-identity 이고 그게 4/4 PASS — 바이너리 md5 는 clang build-path/timestamp 메타로 다를 수 있으나 fixpoint 기준 아님.
