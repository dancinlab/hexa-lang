@title: 🌱 HEXA-CC-ZERO — "마지막 C 씨앗 제거"
@goal: self/native/hexa_cc.c 를 repo에서 완전히 제거한다 — `hexa cc --regen` 이 4개 .hexa SSOT 모듈에서 트랜스파일러를 warm-rebuild 하게 하여, 손으로 유지하던 마지막 C 시드를 없애고 "0 .c" self-host에 도달한다.

# HEXA-CC-ZERO — current state

손-유지 C는 사실상 `self/native/hexa_cc.c`(트랜스파일러 씨앗) 하나만 남았다. 이걸 없애면 컴파일러가 자기 자신을 자기 언어로만 다시 만든다.

## progress

- [x] P1 — `hexa cc --regen` self-host fixpoint byte-eq PASS (cross-host: Mac arm64 #2105 + ubu x86_64) · 🟢 v_n≡v_{n+1} 4/4 모듈 byte-eq + DETERMINISTIC 양 호스트 실측. ⚠ 잔여(P1 fixpoint 성질과 별개): in-tree seed(build/hexat)가 자기 SSOT 의 fixpoint 아님 = stale seed(hexa_int 인라인 #2078 미반영) — 양 호스트 동일 방향. seed 갱신(재regen+커밋)은 후속
- [x] P2 — cross-host kill-storm-free warm-rebuild PASS (mini arm64 + ubu-2 x86_64 둘 다 `cc --regen` RC=0 · 4/4 SSOT transpile OK · merged-C compile OK) · 🟢 Mac kill-storm refuse-gate(`_refuse_local_on_mac`) PRESENT+FIRING(exit 2 + pool 힌트) · pool-offload 경로로만 실행(Mac 워크스테이션 heavy-build 0) · install/seed md5 PRE==POST(read-only). ubu-2 는 `/tmp/hexat.new` ELF working transpiler 까지 링크. ⚠ in-tree seed byte-eq DRIFT 은 P1 의 알려진 stale-seed(P2 축=clean-completion+kill-storm safety, seed byte-eq 아님)
- [x] P3 — stage-(-1) cold-seed TRUE-COLD-PASS cross-host (#2116 design option b 구현) · 🟢 단일 self-contained `self/native/hexa_cc_seed.c`(2.85 MB · 0 local include) 커밋 → bare clone + `cc hexa_cc_seed.c -o hexat`(사전설치 hexa 不要)만으로 작동 트랜스파일러 빌드, x86_64(ubu-2)+arm64(mini) 양 arch 4/4 SSOT transpile rc=0 · DETERMINISTIC · x86_64 는 per-arch fixpoint(gen_b≡gen_c)까지 PASS. ⚠ 잔여(cold-boot 닫힘과 별개): cross-arch strict byte-eq 는 3/4(codegen arch-specific·per-arch deterministic — P1 의 per-arch fixpoint 모델과 일치)
- [x] P5 — cold-seed 부트스트랩 DEFAULT wiring (build_hexa_cli.hexa step 0) · 🟢 #2126 P3 seed 를 "proven capability" → ACTUAL default bootstrap path 로 전환. step 0 가 regen-source `hexa_cc.c` 부재(true fresh clone) + `hexa_cc_seed.c` 존재 시 self-contained seed 에서 직접 `cc hexa_cc_seed.c -o build/hexat`(amalgam sed 없음·-I 없음·0 local include) 부트스트랩 — host hexa·manual step 不要. hexa_cc.c 존재 시 기존 warm amalgam 경로 그대로(dev loop 무변경). TRUE-COLD-DEFAULT ubu-2 x86_64 PASS(verdict 첨부)
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

## 2026-05-30 P1 BYTE-EQ 실측 (ubu x86_64 cross-host · verdict 첨부)

verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-BYTEEQ-UBU.txt` (ubu-2 stdout + per-module md5 verbatim)

직전 Mac 사이클(#2105)은 sibling agent 점유로 ubu x86_64 를 미측정(`⏸`)했다. ubu-2 free → 같은 self-host fixpoint byte-eq 를 ubu-2 x86_64 에서 **실측**해 P1 cross-host 를 닫음. `/tmp` fresh clone of origin/main(ca98235) SSOT + summer `build/hexat` seed 로 2-iteration fixpoint(v_n==v_{n+1}) 측정. install dir 은 `/tmp/hxinst` self-contained copy — 설치 hexa.real(md5 d72b6937, 미변경)·summer seed(md5 4ca3d5d7, 미변경) 무손상.

- 🟢 **self-host fixpoint v_n ≡ v_{n+1} = 4/4 모듈 BYTE-EQ (ubu x86_64)** — gen_b(hexat.new) 출력 vs gen_c(hexat.new2 재transpile) 출력이 lexer/parser/type_checker/codegen 모두 byte-identical (md5 일치). regen 결정성(같은 바이너리 2회)도 4/4 DETERMINISTIC. 후속 iter(gen_c==gen_d)도 STABLE. **트랜스파일러가 자기 SSOT 로부터 자기 자신을 안정적으로 재생산 — Mac arm64(#2105)에 이어 ubu x86_64 에서도 입증 = P1 fixpoint 성질 CROSS-HOST PASS.**
- 🔴 **in-tree seed drift 도 Mac 과 동일 방향으로 재현** — 커밋 seed(summer build/hexat) 출력(gen_a) vs 현 SSOT 출력(gen_b)은 4/4 모듈 DRIFT (lexer 904·parser 320·tc 558·codegen 2728 diff lines). root cause = 현 SSOT codegen 이 정수 리터럴을 인라인 박스 `((HexaVal){.tag=TAG_INT,.i=(N)})` 로 emit(= PR #2078 hexa_int 인라인 · UNSHADOW #2), 커밋 seed 는 그 최적화 前 `hexa_int(N)` 형태. 즉 SSOT 가 NEWER · seed 미갱신 = Mac(153 hunk)과 동일 root. cross-host 일관 = 최종 regen 없이 커밋된 stale seed 의 결정적 신호.
- ✅ **P1 cross-host CLOSED (fixpoint 성질)** — Mac arm64(#2105) + ubu x86_64 양쪽 self-host fixpoint byte-eq 4/4 PASS. P1 체크박스 flip. 단 in-tree seed 갱신(재regen+커밋)은 P1 fixpoint 성질과 **별개** 잔여 — 양 호스트 공통.
- ℹ️ **P3 cold-seed 는 무관·미flip** — P1 byte-eq fixpoint(기존 hexat 존재 전제 warm-rebuild)는 P3 stage-(-1) cold bootstrap(hexa_cc.c 없이 부트스트랩 경로)과 별개 frontier. P3 는 여전히 open. P2/P5/P6 도 미터치.

## 2026-05-30 P3 COLD-SEED 구현 + TRUE-COLD 실측 (verdict 첨부)

verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-P3-COLDBOOT.txt` (양 arch cold-boot stdout + per-module md5 verbatim)

설계 #2116 option(b) 구현 — 단일 self-contained pre-amalgamated C-seed TU `self/native/hexa_cc_seed.c`(2982925 B · md5 6ee710e4) 커밋. hexa_cc.c(4 SSOT transpile+merge = P1 fixpoint) + runtime.c + runtime_core.c + runtime_hi_gen.c + native/*.c + forge_tier_v1.c 전 fragment 를 단일 TU 로 inline (로컬 `#include "..."` 0개). 양 arch 격리 /tmp dir 에서 PATH 의 hexa 제거(subshell scrub) 후 측정 — 설치 hexa.real·Mac toolchain 무손상.

- 🟢 **TRUE-COLD-PASS cross-host** — bare clone(host hexa 없음) + C 컴파일러만으로 작동 트랜스파일러 빌드 성공: x86_64(ubu-2 gcc 13.3) `cc rc=0`→hexat 2244840 B→4/4 SSOT transpile rc=0 + 4/4 byte-eq + per-arch fixpoint(gen_b≡gen_c) ; arm64(mini Apple clang 21) `cc rc=0`→hexat 2269712 B(Mach-O arm64)→4/4 SSOT transpile rc=0 + DETERMINISTIC(run1≡run2). **stage-(-1) chicken-egg 닫힘** — build/hexat 이 bare clone offline 로 도달 가능.
- 🟡 **honest caveat — cross-arch strict byte-eq 는 3/4** — lexer/parser/type_checker 는 x86_64≡arm64 byte-identical, codegen.hexa 만 arch-specific(x86_64 1a9c46dc vs arm64 6e30c168 — string-pool ordering/size 구조차)이나 PER-ARCH DETERMINISTIC. P1(#2105/#2109)이 애초 PER-ARCH fixpoint 였고 cross-arch byte-eq 를 주장한 적 없음 = 일관. cold-boot 도달성(P3 falsifier)은 양 arch PASS.
- ℹ️ **"0 .c" = 0 HAND-WRITTEN .c** — `self/native/hexa_cc.c.hexanoport` 마커 R1. generated seed 는 위반 아님(Go-1.4 C-seed = CANON M3b 자체 선언). 새 파일명이라 `.gitignore`(specific `self/native/hexa_cc.c` 만) 미매칭 = 직접 커밋(sign-gate 불필요).
- ⚠ **잔여(P3 닫힘과 별개)**: ① seed 는 d67dd37 pin(re-pin = `cc --regen` on SSOT 변경) ② cross-arch codegen 결정성은 별도 축 ③ runtime memcap fscanf-NULL(d67dd37 pre-#594 잔재 · HEXA_MEM_CAP_MB 설정 시만 · cold-boot 은 HEXA_MEM_UNLIMITED=1 우회) ④ bootstrap-default wiring(build_hexa_cli Step 0 가 seed 우선) = 후속 사이클.

## 2026-05-30 P5 COLD-SEED 부트스트랩 DEFAULT WIRING + TRUE-COLD-DEFAULT 실측 (verdict 첨부)

verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-P5-BOOTSTRAP.txt` (ubu-2 stdout verbatim + per-module md5)

P3(#2126)의 cold-seed 는 "proven capability"였지만 DEFAULT 부트스트랩(`tool/build_hexa_cli.hexa` step 0)은 여전히 gitignored·fresh-clone-absent 인 `hexa_cc.c` 를 hard-require 했다 (P3 잔여 ④). P5 = step 0 에 **seed-preference branch** 를 wire — surgical 변경(rewrite 아님). `if !_file_exists(hexat)` 안에서 `hexa_cc.c` 부재 AND `hexa_cc_seed.c` 존재 시 self-contained seed 에서 직접 부트스트랩(`cc hexa_cc_seed.c -o build/hexat` · amalgam sed 없음 · `-I` 없음 — seed 가 runtime 을 이미 inline + 0 local include), 아니면 기존 warm amalgam 경로(dev loop 무변경).

- 🟢 **TRUE-COLD-DEFAULT PASS (ubu-2 x86_64 · gcc/cc 13.3.0)** — `origin/<P5 branch>` `/tmp` fresh clone(HEAD e06e3db) → `hexa_cc.c: ABSENT (true fresh clone)` 확인 → PATH scrub(`no hexa`) → step-0 cold branch 명령 그대로 실행: `cc rc=0` → `build/hexat` ELF x86-64 2244456 B → **4/4 SSOT transpile rc=0** (lexer 191259 B · parser 411242 B · type_checker 149174 B · codegen 988769 B). **host hexa 없이 · manual step 없이 build/hexat 도달 = cold-seed 가 ACTUAL default bootstrap path**.
- 🟢 **WARM path 무변경** — `hexa_cc.c` 존재 시 기존 amalgam sed(`runtime.h`→`runtime.c`) + `-I self` 경로가 byte-for-byte 보존(else 분기). 부트스트랩 logic = preference branch 추가일 뿐, 기존 dev 루프 회귀 0. `hexa parse tool/build_hexa_cli.hexa` PASS.
- ℹ️ **codegen md5 6e30c168 = P3 arm64-baseline 과 동일 값(ubu-2 측정)** — codegen.hexa 의 arch-specific PER-ARCH DETERMINISTIC 성질(P1/P3 캐비엇)과 일치, P5 falsifier(cold-boot 도달성)와 무관.
- ✅ **P5 CLOSED** — cold-seed 가 default bootstrap path. P3 잔여 ④ 해소.
- ⚠ **HEXA-CC-ZERO 전체 = NOT-YET-FULLY-CLOSED**: P1✅ · P3✅ · P5✅ 이지만 **P2(cross-host kill-storm-free warm-rebuild)** open · **P6(`hexa_cc.c` git rm + CI green)** open. P6 는 P5 가 닫혔으므로 이제 unblocked(seed 가 부트스트랩하므로 hexa_cc.c 제거 가능)이나 CI/fresh-clone green 의 형식 종결은 별도 사이클. fully-closed = P1+P2+P3+P5+P6 (현 3/5).

## 2026-05-30 P2 CROSS-HOST KILL-STORM-FREE WARM-REBUILD 실측 (verdict 첨부)

verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-P2-KILLSTORM.txt` (Mac refuse-gate firing + mini/ubu-2 warm-rebuild stdout verbatim + read-only md5 PRE/POST)

P2 falsifier = WARM-rebuild(`hexa cc --regen`, 기존 host hexa 로부터)가 Mac arm64(mini) AND ubu x86_64(ubu-2) 둘 다 **pool-offload 경로**로 깨끗이 완료(2026-05-23 kick-storm Mac-kill 재발 없이)되는가 + Mac refuse-gate 가 un-offloaded Mac-local heavy build 를 실제로 막는가. 측정은 `pool on mini`/`pool on ubu-2` — Mac 워크스테이션은 절대 heavy-build 하지 않음(그게 이 milestone 이 막는 kill-storm risk). install hexa.real·in-tree seed md5 PRE 캡처 → POST 복원·재검증(read-only).

- 🟢 **Mac kill-storm REFUSE-GATE PRESENT + FIRING** — 컴파일된 `tool/build_hexa_cli.hexa` 의 `main()` 이 `_refuse_local_on_mac()`(L117: Darwin AND `LOCAL_BUILD!=1` → refuse) 을 `_do_build` 前에 호출. Mac 워크스테이션에서 `LOCAL_BUILD` 없이 실행 → **exit 2** + kill-storm 힌트(`pool on mini …` 오프로드 권장 + `LOCAL_BUILD=1` 강제 옵션) 출력, heavy work 미실행. `LOCAL_BUILD=1` 은 게이트 우회(아래 _do_build 진입 — Mac 안 부수려 timeout abort). **countermeasure 작동 입증.**
- 🟢 **mini (Darwin arm64) warm-rebuild PASS** — self-consistent tree(P1 verdict 동일 트리, af645e419: hexat+hexa_cc.c[1848771B]+SSOT+runtime.c 동일 source) 에서 `cc --regen` **RC=0** · [1/4] 4/4 SSOT(lexer/parser/tc/cg) transpile OK · [2/4] merge → hexa_cc.c.new 1848179B/28401L · [3/4] **merged-C clang compile OK**(/tmp/hexa_cc.new.o, 0 error, -Wcomment 경고 2건만). link 단계만 runtime.o 미사전빌드로 실패(read-only run artifact — fixpoint 은 merged-C source/.o 기준이고 그건 compile). build/hexat·hexa_cc.c·hexa.real md5 PRE==POST.
- 🟢 **ubu-2 (Linux x86_64) warm-rebuild PASS (full transpiler)** — tree(d67dd371: hexat ELF + runtime.o PRESENT) 에서 `cc --regen` **RC=0** · 4/4 SSOT transpile OK · merge → hexa_cc.c.new 1855815B/28493L · **merged-C compile AND LINK OK**(`compiled=yes`) → `/tmp/hexat.new` = **ELF x86-64 working transpiler** 생성. build/hexat·hexa.real md5 PRE==POST. (mini 보다 강한 증거: 컴파일된 .o 가 아니라 full warm-rebuilt 트랜스파일러 바이너리.)
- ✅ **P2 CLOSED** — (a) warm regen 양 호스트 clean-completion(RC=0·4/4 SSOT·merged-C compile) + (b) Mac refuse-gate FIRES. P2 체크박스 flip.
- ⚠ **HONEST caveat (g5/g63)**: ① in-tree-seed byte-eq DRIFT 은 P1 이 이미 문서화한 stale-seed 조건 — P2 축이 아님(P2=clean-completion+kill-storm safety). ② per-arch codegen 결정성(P1/P3)상 cross-arch strict byte-eq 는 P2 요구사항 아님 — mini·ubu-2 각각 per-arch clean warm-rebuild. ③ mini link-only 실패는 read-only run(runtime.o 의도적 미빌드) artifact, ubu-2(runtime.o 존재)는 full transpiler 까지 링크 = warm path 가 runtime.o 존재 시 양 arch 에서 working transpiler 도달 확인.
- ⚠ **HEXA-CC-ZERO 전체 = 4/5 (P1✅·P2✅·P3✅·P5✅)** — 남은 단 하나 **P6(`hexa_cc.c` git rm + CI/fresh-clone green 형식 종결)** 만 open. P5(cold-seed default bootstrap) + P2(warm-rebuild cross-host) 닫힘으로 P6 는 완전 unblocked — `git rm`(파일은 이미 origin/main 에서 untracked+MISSING) + CI green 형식 확인만 남음. fully-closed = P1+P2+P3+P5+P6 (현 4/5, P6 만 잔여).
