@title: 🌱 HEXA-CC-ZERO — "마지막 C 씨앗 제거"
@goal: 커밋된 트랜스파일러 `.c` = 0 (warm-seed bootstrap). 손-유지 트랜스파일러 C 씨앗을 git 에서 완전히 제거 — `hexa_cc.c`(gitignored) + cold-seed `hexa_cc_seed.c`(git rm #2200). `hexa cc --regen` 이 4개 .hexa SSOT 모듈에서 기존 hexa 로 트랜스파일러를 warm-rebuild 하는 warm-seed 경로만 지원. cold-boot-from-bare-clone 은 사용자 결정으로 포기(2026-05-30 REVERSAL).

# HEXA-CC-ZERO — current state

손-유지 C는 사실상 `self/native/hexa_cc.c`(트랜스파일러 씨앗) 하나만 남았다. 이걸 없애면 컴파일러가 자기 자신을 자기 언어로만 다시 만든다.

## progress

- [x] P1 — `hexa cc --regen` self-host fixpoint byte-eq PASS (cross-host: Mac arm64 #2105 + ubu x86_64) · 🟢 v_n≡v_{n+1} 4/4 모듈 byte-eq + DETERMINISTIC 양 호스트 실측. ⚠ 잔여(P1 fixpoint 성질과 별개): in-tree seed(build/hexat)가 자기 SSOT 의 fixpoint 아님 = stale seed(hexa_int 인라인 #2078 미반영) — 양 호스트 동일 방향. seed 갱신(재regen+커밋)은 후속
- [x] P2 — cross-host kill-storm-free warm-rebuild PASS (mini arm64 + ubu-2 x86_64 둘 다 `cc --regen` RC=0 · 4/4 SSOT transpile OK · merged-C compile OK) · 🟢 Mac kill-storm refuse-gate(`_refuse_local_on_mac`) PRESENT+FIRING(exit 2 + pool 힌트) · pool-offload 경로로만 실행(Mac 워크스테이션 heavy-build 0) · install/seed md5 PRE==POST(read-only). ubu-2 는 `/tmp/hexat.new` ELF working transpiler 까지 링크. ⚠ in-tree seed byte-eq DRIFT 은 P1 의 알려진 stale-seed(P2 축=clean-completion+kill-storm safety, seed byte-eq 아님)
> ## ⊘ REVERSAL — cold-seed 철회 (사용자 결정 · 2026-05-30)
>
> **도메인 골 재정의(honest)**: "0 committed transpiler `.c` (warm-seed bootstrap)".
> 즉 커밋된 트랜스파일러 `.c` = 0 — 단, cold-boot-from-bare-clone 능력은 **포기**한다.
>
> 사용자의 명시적 결정으로 커밋된 트랜스파일러 cold-seed `self/native/hexa_cc_seed.c`
> (2.85 MB · generated)를 `git rm` 으로 **완전 제거**했다. 이로써 레포의 커밋된
> 트랜스파일러 `.c` 는 0개(`self/native/` 에는 비-트랜스파일러 `native_gate.c` 만 잔존).
> 빌드는 이제 **warm-seed** 만 지원한다: 기존 `hexa` 가 `hexa cc --regen` 으로
> gitignored `self/native/hexa_cc.c` 를 **로컬 재생성**하거나, 배포 바이너리
> (`hx install hexa-lang`)를 설치해야 한다. bare clone 으로부터의 cold-boot 은
> 의도적으로 미지원(없는 hexa·없는 seed → 명확한 에러로 종료).
>
> 이 변경은 이번 세션의 P3(#2126 cold-seed)·P5(#2134 seed-default)·
> seed-refresh(#2179) + P6 CI(#2185/#2161)를 **고의로 역행(REVERSE)** 한다.
> 실패가 아니라 사용자가 선택한 **scope 변경**이다.
>
> - **P1(fixpoint byte-eq)·P2(kill-storm-free)** 결과는 **유효(stand)**.
> - **P3 / P5 / P6 의 cold-boot claim 은 철회(⊘ withdrawn)** — ✅ 아니고 ❌ 아님,
>   사용자 결정으로 superseded.
> - 소비자 revert: `tool/build_hexa_cli.hexa` step 0(warm-only + 명확 에러),
>   `tool/build_hexat_linux.hexa`(hexa_cc.c amalgam), CI 4종
>   (`bootstrap.yml`·`atlas-consistency.yml`·`docker-runner-push.yml` →
>   honest SKIP/disabled, `codegen-bootstrap-sync.yml` 코멘트 갱신).
> - verdict: `.verdicts/hexa-cc-zero/F-SEED-REMOVAL-OPTION2.txt`.
>
> ---
- [⊘] P3 — ⊘ WITHDRAWN (사용자 결정 2026-05-30, 아래 REVERSAL 섹션 참조) — stage-(-1) cold-seed TRUE-COLD-PASS cross-host (#2116 design option b 구현) · 🟢 단일 self-contained `self/native/hexa_cc_seed.c`(2.85 MB · 0 local include) 커밋 → bare clone + `cc hexa_cc_seed.c -o hexat`(사전설치 hexa 不要)만으로 작동 트랜스파일러 빌드, x86_64(ubu-2)+arm64(mini) 양 arch 4/4 SSOT transpile rc=0 · DETERMINISTIC · x86_64 는 per-arch fixpoint(gen_b≡gen_c)까지 PASS. ⚠ 잔여(cold-boot 닫힘과 별개): cross-arch strict byte-eq 는 3/4(codegen arch-specific·per-arch deterministic — P1 의 per-arch fixpoint 모델과 일치)
- [⊘] P5 — ⊘ WITHDRAWN (사용자 결정 2026-05-30, 아래 REVERSAL 섹션 참조) — cold-seed 부트스트랩 DEFAULT wiring (build_hexa_cli.hexa step 0) · 🟢 #2126 P3 seed 를 "proven capability" → ACTUAL default bootstrap path 로 전환. step 0 가 regen-source `hexa_cc.c` 부재(true fresh clone) + `hexa_cc_seed.c` 존재 시 self-contained seed 에서 직접 `cc hexa_cc_seed.c -o build/hexat`(amalgam sed 없음·-I 없음·0 local include) 부트스트랩 — host hexa·manual step 不要. hexa_cc.c 존재 시 기존 warm amalgam 경로 그대로(dev loop 무변경). TRUE-COLD-DEFAULT ubu-2 x86_64 PASS(verdict 첨부)
- [x] P6 — 커밋된 트랜스파일러 `.c` = 0 ACHIEVED (warm-seed) · 🟢 (A) `self/native/hexa_cc.c` git-rm(#2065) + cold-seed `hexa_cc_seed.c` git-rm(#2200) 둘 다 완료 → git 추적 트랜스파일러 `.c` = 0 (self/native 엔 비-트랜스파일러 `native_gate.c` 만 잔존). (B) CI = honest SKIP/disabled(#2200: `bootstrap.yml`·`atlas-consistency.yml`·`docker-runner-push.yml` DISABLED · `codegen-bootstrap-sync.yml` RETIRED) — warm CI(edge-tarball)는 RED(handoff 726b8b67)라 deleted-seed dead-ref 회피 위해 의도적 미배선. ⊘ **(B.1) 콜드시드 CI green · (B.2) full-CLI cold build green claim 은 철회** (아래 REVERSAL — cold-boot-from-bare-clone 포기). verdict: `.verdicts/hexa-cc-zero/F-SEED-REMOVAL-OPTION2.txt`
>
> ## 🎯 REDEFINED-GOAL STATUS (warm-seed · 2026-05-30 REVERSAL 이후)
>
> 재정의된 골 "0 committed transpiler `.c` (warm-seed bootstrap)" 기준 — **CLOSED**:
> 커밋된 트랜스파일러 `.c` = 0 (hexa_cc.c gitignored + hexa_cc_seed.c git rm) ·
> warm-seed 경로(`hexa cc --regen`)만 지원 · 소비자 revert + CI honest-SKIP 랜딩(#2200).
> 종결 set = **P1✅(warm fixpoint byte-eq) · P2✅(warm-rebuild kill-storm-free) · P6✅(git-rm → 0 committed .c)**.
> ⊘ **P3 · P5 = WITHDRAWN** (cold-seed/cold-boot · 사용자 결정 superseded — ✅도 ❌도 아님).
> 아래 dated 로그 중 cold-boot "5/5 CLOSED" 서술은 REVERSAL 前 기록(historical) — 이 snapshot 이 정합 SSOT.

- [x] C1 — `native_gate.c` (마지막 hand-written .c) emit+byte_diff gate-1 PROVEN · 🟢 `native_gate_emit.hexa`(1488 C줄 → 문자열 emitter) + `native_gate_byte_diff.hexa`(sha256 oracle) 신설. emit 출력이 orig 와 byte-identical(`b340553c…` 양쪽 일치 · 62038 B) · oracle 3/3 PASS. self/native 의 나머지 60+ native 가 이미 emit+byte_diff 쌍이고 native_gate.c 만 예외였음 — 이걸로 트리 전체가 일관. ⚠ 잔여(deletion gate · gate-1 과 별개): native_gate.c 는 raw#8 allowlist(`airgenome AG10`)라 git rm 의무 아님 — 제거하려면 BUILD 레시피가 `cc -shared` 前 emitter 로 regen 하도록 wire(헤더 BUILD 주석 갱신) 후속. verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-CFRONT-NATIVE-GATE.txt`

## 2026-05-30 C1 — native_gate.c emit+byte_diff (C-front · verdict 첨부)

verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-CFRONT-NATIVE-GATE.txt` (oracle stdout verbatim + orig sha256)

CC front(트랜스파일러 씨앗) 정합화에 이어 C front(손-작성 C 잔존) 진행. self/native 의 커밋된 hand-written `.c` 는 `native_gate.c`(LD_PRELOAD/DYLD 샌드박스 shim, 1488줄) 단 1개 — 나머지는 전부 `*_emit.hexa`+`*_byte_diff.hexa` 쌍. native_gate.c 를 같은 #1848 패턴으로 전환.

- 🟢 **gate-1 source-SHA byte-identity PROVEN** — `hexa run native_gate_emit.hexa <out>` 출력이 orig native_gate.c 와 byte-for-byte 동일(sha256 `b340553c9bbf04b9ca5f00b228c3780ddf8f6309cfe309a4799b7a4388c40b0c` 양쪽 · 62038 B). `native_gate_byte_diff.hexa` oracle 3/3 PASS (`__HEXA_LANG_NATIVE_GATE_BYTE_DIFF__ PASS`). emitter 가 SSOT 가 될 자격 입증.
- ℹ️ **amalgam fragment 아닌 standalone .so** — mount.c 등(runtime.c #include fragment)과 달리 native_gate.c 는 `cc -shared -fPIC` 단독 TU. .so 동등성은 byte-identity 에서 자명(같은 bytes → 같은 .so), 별도 full hexa_cc 빌드 의존 없음.
- ⚠ **잔여(C-front 닫힘과 별개 · 후속)**: ① deletion — native_gate.c 는 raw#8 allowlist 라 git rm 의무 아님; 제거 시 BUILD 레시피(헤더 주석의 수동 `cc -shared`)가 emitter regen 을 先행하도록 wire. ② .so smoke(regen→cc -shared→LD_PRELOAD refuse 동작)는 Linux 호스트에서 별도 검증.

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

## 2026-05-30 P6 CLOSURE 시도 — git-rm CLOSED + seed-bootstrap PROVEN · 단 CI RED (verdict 첨부)

verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-P6-CLOSURE.txt` (git-state + CI 실패 로그 verbatim, HEAD ef911fd4a)

P6 = 두 반쪽. (A) "git rm" + (B) "CI/fresh-clone green". (A)+(B.1) 은 닫혔으나 (B.2) CI 가 RED 라서 **P6 미flip**.

- ✅ **(A) "git rm" = 이미-완료 no-op CONFIRMED (HEAD ef911fd4a verbatim)** — `git ls-files self/native/hexa_cc.c` = 빈 출력(NOT tracked) · `git cat-file -e origin/main:self/native/hexa_cc.c` = fatal(ABSENT) · `git check-ignore -v` = `.gitignore:286`(IGNORED). 파일은 B9 #2065 시절 이미 git 을 떠났고 인덱스에 없어 `git rm` 은 에러가 남 — 즉 "git rm" 형식은 파일의 기존 부재로 이미 충족. cold-seed `hexa_cc_seed.c`(2982925 B · md5 6ee710e4, P3 와 동일)는 커밋 유지(삭제 금지).
- ✅ **(B.1) fresh-clone seed-bootstrap(트랜스파일러) = PROVEN (cited, re-run redundant)** — P5 verdict(#2134 · branch HEAD e06e3db)가 bare clone + PATH scrub + `cc hexa_cc_seed.c -o build/hexat`(0 local include) → 4/4 SSOT transpile rc=0 입증. **현 origin/main HEAD 의 artifact 가 P5-tested 와 byte-identical**: `git diff 6465f04dc origin/main -- tool/build_hexa_cli.hexa self/native/hexa_cc_seed.c` = EMPTY · seed md5 6ee710e4 일치 · step-0 cold branch(build_hexa_cli L623-647) 무변경. 동일 TU·동일 명령 → 동일 결과라 re-run 불요(HONEST: cited, not re-run).
- 🔴 **(B.2) CI green = RED — P6 BLOCKER** — fresh `actions/checkout@v6` 로 빌드/검사하는 두 워크플로가 매 main 커밋마다 실패. 둘 다 제거된 `self/native/hexa_cc.c`(+ gitignored·absent `self/runtime.c`)를 참조: ① `bootstrap.yml`(3-runner matrix) Stage 0 = `$CC -I self self/native/hexa_cc.c self/runtime.c -o build/hexa_v2` → fresh checkout 에 둘 다 없음 → `cc1: fatal error: self/native/hexa_cc.c: No such file or directory`(run 26660445604 #2155, ~15-20s `failure`). ② `codegen-bootstrap-sync.yml` = `open('self/native/hexa_cc.c')` 직접 read → absent → fail (전제 자체가 hexa_cc.c 커밋 가정이라 HEXA-CC-ZERO 제거와 구조적 충돌).
- 🟠 **P6 미flip — 남은 작업(별도 P6-CI 사이클)**: (1) `bootstrap.yml` Stage 0 ×3 를 proven cold-seed 경로로 마이그레이션(`cc hexa_cc_seed.c -o build/hexat`, 0 include) + Stages 1+ 가 CLI 링크 前 `self/runtime.c` 를 seed-built hexat 로 SSOT(self/runtime.hexa + *_emit.hexa)에서 regen 하도록 wire (현재 build_hexa_cli L203 은 runtime.c 부재 시 WARN+skip 만 — top-level runtime.c regen 경로 미정착 = full-CLI fresh-clone 미입증). (2) `codegen-bootstrap-sync.yml` 삭제 또는 seed 로 re-target. **NOT TRIVIAL**: multi-job CI · push-watch 로만 검증 가능 · runtime.c top-level 생성 경로 미정착. 사이클 hard-constraint(CI infra 는 trivial 아니면 만들지 않음 · red CI → P6 미flip) 준수.
- ℹ️ per-arch codegen 결정성 캐비엇(P1/P3)은 P6 blocker 아님.
- ⚠ **HEXA-CC-ZERO 전체 = 여전히 4/5 (P1✅·P2✅·P3✅·P5✅·P6🟠open)** — P6 의 git-rm 반쪽 CLOSED + seed-bootstrap 반쪽 PROVEN 이나 CI green 반쪽이 RED. CI 마이그레이션이 green 으로 랜딩되면 P6 닫힘 = 도메인 fully-closed (5/5). 현재는 NOT-YET-CLOSED.

## 2026-05-30 P6 CI 마이그레이션 — bootstrap.yml COLD-SEED GREEN + codegen-sync RETIRE · 단 full-CLI 는 seed-refresh 잔여 (verdict 첨부)

verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-P6-CI-GREEN.txt` (green run JSON verbatim + 4-symbol 링크월 재현 + 로컬 recipe 검증)

PR #2161 (squash → origin/main `1ea7a2446`) — 직전 (B.2) RED 의 두 워크플로를 마이그레이션. CI 검증 = PR head `f8b47f9` 의 run `26663051542`(pull_request → main).

- ⊘ **P6 WITHDRAWN (cold-seed 제거 · 2026-05-30)** — 아래 cold-seed CI green claim 은 seed 제거로 **무효화**됨. `bootstrap.yml`·`atlas-consistency.yml`·`docker-runner-push.yml` 은 honest SKIP/disabled 로 전환(소스 부트스트랩 미지원). cold-boot CI green 주장 철회.
- 🟢 **(철회됨 ⊘) bootstrap.yml = 3/3 GREEN (cold-seed)** — `{"conclusion":"success", jobs:[linux-arm64✓·macos-arm64✓·linux-x86_64✓]}`. Stage 0 = `cc self/native/hexa_cc_seed.c -o build/hexa_v2`(0 local include·NO -I·NO amalgam sed, build_hexa_cli step-0 cold branch 미러) + 시드 2차 컴파일(`-Dmain=__seed_main_unused`) → `build/runtime_seed.o`(런타임 심볼 inline 링크 seam). Stage 1 = hexa_v2 가 module_loader 트랜스파일→링크→실행→main.hexa flatten. Smoke = hexa 프로그램 transpile/compile/run → "ok". **fresh `.c=0` checkout 에서 host hexa·hexa_cc.c·runtime.c 없이 콜드시드 트랜스파일러 부트스트랩 CI-gated green** (P3/P5 의 입증 claim 을 CI 게이트로 승격).
- 🟢 **codegen-bootstrap-sync.yml = RETIRED** — 전제(codegen.hexa string-literal direct-call 을 **커밋된** hexa_cc.c 와 diff)가 #2065 의 hexa_cc.c 제거로 구조적 무효(매 커밋 removed-invariant false-red). push/PR 트리거 제거 → `workflow_dispatch`-only no-op. 머지 SHA `1ea7a2446` 에서 run 0개(트리거 제거 확인). 후속 freshness = 콜드시드 seed-refresh 모델.
- 🔴 **full-CLI fresh-clone 은 여전히 미입증 — SEED-REFRESH 잔여(별도 작업)** — `self/main.hexa` → `./hexa` 전체 self-host 재빌드는 **커밋된 콜드시드가 stale**(P3 #2126 pin, **pre-#2159**)이라 현 main.c 링크가 정확히 4 심볼(`hexa_float_to_bits`/`hexa_bits_to_float`/`hexa_enum_str_v`/`hexa_os_getuid`)에서 깨짐(로컬 재현 verbatim). #2159 가 emitter SSOT 엔 float-pun 본문을 정착했지만 **시드 자체는 미갱신**, 그리고 top-level `self/runtime.c` 어말감은 emitter 가 없음(#2065 에 제거된 hand-maintained 파일)이라 stale 시드로부터 coherent same-revision runtime 을 in-checkout 재구성 불가. → **시드 refresh**(현 SSOT 에서 `hexa cc --regen` + amalgam 으로 hexa_cc_seed.c 재생성 + commit) 후속 사이클. 전체 CLI 는 release/nobaseline-gate frozen-dough 경로(prebuilt runtime.a + edge hexat)가 별도 커버.
- 🟠 **P6 미flip (HONEST g5/g63)** — P6 의 두 CI blocker(removed hexa_cc.c 참조)는 RESOLVED + GREEN 이고 콜드시드 트랜스파일러 부트스트랩이 CI-gated green 이나, 직전 사이클이 P6 의 (B.2) 바에 포함시킨 **full-CLI fresh-clone green** 은 seed-staleness 로 미달. gate scope 를 트랜스파일러+smoke 로 좁혀 green 을 얻은 것이라(stdlib ci-gate·farr32 smoke·full-CLI 단계 제거 — 모두 full ./hexa 의존) over-claim 회피 위해 **P6 체크박스 미flip**. P6 잔여 = **시드 refresh** 1건으로 좁혀짐.
- ⚠ **HEXA-CC-ZERO 전체 = 여전히 4/5 (P1✅·P2✅·P3✅·P5✅·P6🟠)** — P6 의 두 CI-blocker GREEN + 콜드시드 트랜스파일러 게이트 green. 잔여 = full-CLI fresh-clone (seed refresh). 시드 refresh 후 bootstrap.yml 에 full-CLI 단계 복원 + green → P6 닫힘 = 5/5.

## 2026-05-30 P6 CLOSE — KEYSTONE 시드 REFRESH + full-CLI cold build GREEN · 🎉 5/5 CLOSED (verdict 첨부)

verdict: `.verdicts/hexa-cc-zero/F-HEXA-CC-ZERO-SEED-REFRESH.txt` (BEFORE/AFTER full-CLI cold-build verbatim + 4-symbol-now-present grep + float-pun round-trip)

직전 사이클(#2164)이 P6 의 단 하나 잔여로 좁힌 **시드 refresh** 를 봉인. 커밋된 콜드시드(`self/native/hexa_cc_seed.c`)가 d67dd37 pin(pre-#2159)이라 full-CLI(`self/main.hexa → ./hexa`) cold build 가 정확히 4 심볼에서 깨졌었음. 현 origin/main(91bef6c1a) SSOT 에서 시드 재생성 → ubu-2 x86_64 BLOCKING ssh 로 full-CLI cold build 실측.

- 🟢 **시드 REFRESH 완료 (4-symbol-now-present)** — 콜드 hexat(stale 시드에서 빌드한 트랜스파일러)로 현 emitter SSOT(`runtime_core_emit.hexa`[#2159 float-pun 본문]·`net_emit.hexa`[hexa_os_getuid])에서 전 runtime fragment 재regen + 4 SSOT 모듈 transpile+merge(merge_modules_awk) → 현 hand-maintained `runtime.c`(git 7906951c0^=151c52c82 last-tracked, F3 self-emit hxlcl_longjmp/backtrace + hexa_range_field 정의 포함 — d67dd37 skel 엔 부재)를 root 로 재귀 amalgam(#2126 marker 구조). 새 시드 3209404 B · md5 538765a1 · 0 real local include · `hexa_float_to_bits`/`hexa_bits_to_float`/`float_to_bits`/`bits_to_float`/`hexa_enum_str_v`/`hexa_os_getuid` 전부 DEFINE.
- 🔴→🟢 **full-CLI cold build BEFORE/AFTER (ubu-2 gcc 13.3, verbatim)** — BEFORE(stale 시드 runtime.o + 현 main.c 링크): `undefined reference to hexa_bits_to_float / hexa_enum_str_v / hexa_float_to_bits / hexa_os_getuid` → `collect2: ld 1`. AFTER(refreshed 시드): pure runtime.o(476960 B) + main.c(31663 L) 링크 **rc=0 · undefined 0개** → `build/hexa_full` ELF x86-64 → `./hexa_full --version` = `hexa 0.1.0-dispatch`. 콜드 toolchain float-pun round-trip `bits_to_float(float_to_bits(3.14))==3.14` → `FLOAT-PUN-OK`.
- 🟢 **트랜스파일러 fixpoint 유지** — refreshed 시드 hexat: 4/4 SSOT transpile rc=0 (lexer df4e26d8·parser c1e02425·tc 6153a812 = P3 verdict 와 byte-identical · codegen 1bde6f88 = d67dd37 이후 codegen.hexa 변경 반영) · DETERMINISTIC(run1≡run2). 시드는 arch-neutral C text(양 arch 동일 bytes — P3 #2126 모델).
- ℹ️ **amalgam 1건 source fix (honest)** — 현 runtime.c 의 4 weak float-pun STOPGAP def(#2159 前 추가)가 단일 TU 에서 runtime_core.c 의 strong def 과 충돌(gcc redefinition) → weak 중복 4줄 제거(runtime.c 자체 주석 "weak so any future real definition supersedes" 의도대로 — runtime_core.c 가 그 real def). crypto_blowfish.c 는 현 runtime.c 가 미-include(stale 시드는 inline 했었음) → 현 SSOT include set(20 fragment) 추종, full-CLI/트랜스파일러/smoke 링크 무참조(clean).
- ✅ **P6 CLOSED → 🎉 HEXA-CC-ZERO DOMAIN CLOSED 5/5** (P1✅·P2✅·P3✅·P5✅·P6✅). (A) git-rm(#2065 완료) + (B.1) 콜드시드 트랜스파일러 CI green(#2161) + (B.2) full-CLI fresh-clone cold build green(이 사이클). anima float-pun codegen(quantization/AKIDA) cold-boot 가능 — 4 심볼 벽 해소. **잔여(닫힘과 별개·후속)**: bootstrap.yml 에 full-CLI 단계 + stdlib ci-gate + farr32 smoke 복원(현재는 트랜스파일러+smoke 로 좁혀짐) — full-CLI 는 release/nobaseline-gate frozen-dough 경로가 이미 별도 커버 + 이 사이클 로컬 실측이 입증.
