# INBOX — log

Append-only history sister of `INBOX.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-25T05:10Z — demiurge 7-verb production 갭: 10+2 도메인 cellrun per-verb 스크립트 부재 (from: demiurge CLI+COCKPIT 전 도메인 캠페인)

demiurge cockpit/CLI 에서 **21 도메인 × 7-verb 전수 실측** 결과. dispatch 는 21/21 보편 작동(0 crash) — production(측정 record 생산)은 hexa-lang `stdlib/<도메인>/` per-verb 스크립트 배선도에 정확히 비례. demiurge surface 는 완성(dispatch·관찰·정직기록); 남은 건 stdlib 스크립트 (@D d3 — impl home = hexa-lang).

**실측 매트릭스** (✅=record 생산 · ⏭=honest-skip[스크립트 부재] · ·=cell무/no-record):
```
full 7/7   chip · firmware
partial    sscb 6 · bio 5 · matter 4 · component 2 · cern/aura/chem 1
미배선 0/7 antimatter bot brain energy fusion grid mobility rtsc scope space  (전부 ⏭)
no-stdlib  clinical · ufo  (· — stdlib 디렉토리/per-verb cell 부재)
```

**루트코즈**: `.demi` 매니페스트(demiurge/domains/<도메인>.demi)가 `script = stdlib/<도메인>/<verb>.py` 를 cell 마다 선언하나, 그 per-verb 엔트리 스크립트가 hexa-lang 에 없음. 예 — `antimatter.demi [cell.verify] script=stdlib/antimatter/verify.py` 선언하지만 실제 디렉토리엔 `geant4_verify.py`·`pdg_lookup.py` 만 존재(이름 불일치) → cellrun.hexa 가 `verify.py` 못 찾고 honest-skip. 즉 **엔진 로직은 일부 존재하나 cellrun per-verb 엔트리포인트로 미연결**.

- [ ] **10 미배선 도메인 per-verb 엔트리** — `stdlib/<도메인>/<verb>.py` 신규 또는 기존 descriptive 스크립트(geant4_verify.py 등)로 라우팅하는 **thin argv shim**. 최소비용 = shim (verify.py → geant4_verify 호출).
- [ ] **clinical · ufo** — stdlib 디렉토리/per-verb cell 자체 부재 → 신규 작성 (또는 demiurge 측 .demi 매니페스트 생성 선행 확인).
- [ ] **(option) cellrun.hexa fallback** — per-verb `<verb>.py` 없을 때 `stdlib/<도메인>/` 의 descriptive 스크립트를 auto-discover 하는 해석 fallback → 10 도메인 일괄 unblock 가능.
- 참조 패턴: `chip`/`firmware`(full 7/7 wired) · `bio`(substrate=hexa → bio.hexa root dispatcher 로 specify/structure/design/analyze 충족). demiurge 측 액션 무관 — 본 핸드오프는 hexa-lang stdlib 작업.

## 2026-05-25T04:20Z — codegen: 함수 간 동명 `let` comptime-const fold 충돌 ("이름 도둑") — RESOLVED #829

**중복 핸드오프 통합** — 동일 루트코즈 2건을 1건으로:
- anima MODERNIZE M6 (INBOX #824) — #829 fix 의 원 reporter.
- demiurge CARDIO+ X10 PAPER (`_paper.hexa`) — `_cmd_compile` 의 `let pdf = "pdflatex …"`(string literal)가 `_cmd_lint` 의 `let pdf = dir + "/main.pdf"`(non-literal)를 덮어씀 → lint 가 엉뚱한 문자열을 `test -e` → 실제 10p PDF인데 FAIL.

**루트코즈**: codegen 의 comptime-const fold 테이블이 module-global 이라, 한 함수의 `let <id> = <literal>` 이 다른 함수의 동명 `<id>` 까지 stale 리터럴로 inline. `gen2_fn_decl` 이 본문 emit 시 comptime-const scope mark/restore 를 안 걸어 fn 경계에서 fold 가 누수 (block/loop/arm 본문은 이미 mark/restore 됨). silent wrong-answer (build-clean, 잘못된 출력). → [[reference_comptime_fold_shadow_family]] (D17 #724 · D18 #766 · F-FOLD #797 동일 뿌리).

**3-function 최소 repro** (string 변종 = _paper.hexa 패턴):
```
fn cmd_compile() -> str { let pdf = "pdflatex -interaction=nonstopmode"; return pdf }
fn cmd_lint(dir: str) -> str { let pdf = dir + "/main.pdf"; return pdf }
fn main() {
    let _ = cmd_compile()
    println(cmd_lint("/work/paper"))   // 버그: "pdflatex …" · 정상: "/work/paper/main.pdf"
}
```

- [x] **RESOLVED on main by #829** (`9e7ed729 fix(codegen): scope-isolate comptime-const folds per fn body`) — `gen2_fn_decl` 본문 emit 루프를 `_comptime_const_scope_mark()`/`_comptime_const_scope_restore()` 로 감쌈 (block/loop/arm 과 동일 패턴). module-level const 는 유지, per-fn fold 는 fn 종료 시 폐기.
- [x] **검증** (2026-05-25, from-main 트랜스파일러): 위 string repro 5× transpile → emitted C md5 동일(결정적) · 0/5 가 `cmd_lint` 에 stale 리터럴 inline (전부 `hexa_add(dir, "/main.pdf")` 클린) · 실행 `/work/paper/main.pdf` PASS. #829 의 int/float repro(2147483648 → 10.0) 도 동일 PASS. → string 케이스 포함 fix 확정. (workaround 미적용 — 근본수정 우선 원칙대로.)
- [x] **배포 갭 (closed 2026-05-25)**: 배포 refresh = `git switch main` (또는 `cp <fresh-worktree>/self/native/hexa_v2 /Users/ghost/core/hexa-lang/self/native/hexa_v2`). driver `hexa.real` 자체는 thin dispatch only — 진짜 fix 는 `self/native/hexa_v2` 안에 있음. consumer 가 main branch 로 checkout 한 시점에 #829+#862 양쪽 모두 자동 픽업됨. (driver 도 #862-built 로 새로 받고 싶으면: `cp /tmp/hexa.real.new /Users/ghost/core/hexa-lang/hexa.real`.)

## 2026-05-25T03:00Z — codegen: 파라미터명이 호출부 struct 필드명과 같으면 미스컴파일 — RESOLVED #862

- [x] **RESOLVED on main by #862** (`fix(codegen): r16 — param-fold-leak — fn param shadows enclosing comptime-const`). **재해석**: 진짜 트리거는 호출부 struct 필드 alias 가 아니라 모듈 레벨 `const <name> = <literal>` 가 comptime-const fold 테이블에 `<name> → <literal>` 을 등록 → 같은 이름 fn 파라미터의 body Ident 읽기가 `_lookup_comptime_const(<name>)` 에서 stale literal 을 inline (codegen.hexa:4891). 핸드오프 원 reporter 가 본 `len 1 = "x"` 는 stub `Ev { kind: "X", raw: "x", id: "stub" }` 류 const-folded literal 이 누수된 결과. #829 fix 가 fn body scope-isolate 는 잡았지만 param 진입 시 invalidate 가 빠져 있었음. → [[reference_comptime_fold_shadow_family]] family 의 한 갈래.
- [x] **fix** (#862): `gen2_fn_decl` 진입 시 각 `node.params[i].name` 을 `_invalidate_comptime_const` 로 fold 테이블에서 제거 — `_comptime_const_scope_mark` BEFORE (restore 는 truncate-only 라 AFTER invalidate 면 OOB). for-loop counter 패턴 (codegen.hexa:3262/3288) 과 동일 순서.
- [x] **검증**: minimal repro (const raw="x" + fn show(kind,raw,id)) 전후 `len=1 v='x'` → `len=21 v='PAYLOAD-…'`. #829 repro 회귀 PASS. fixpoint gen2≡gen3 byte-eq (md5 9153ebf2316578cf2361b8347d7fa340). 풀 self-host 빌드 PASS.

## 2026-05-25T02:10Z — hexa cloud 개선 4건 (from: demiurge TTR-MN M5 cluster DFT 실전)

M5 cluster DFT (vast `rent` H100 + NWChem PBE0) 실전 중 발견. 전부 우회 가능했으나 SSOT 기록:
- [ ] **preflight DFT/MD 축 부재** — 현재 `preflight`는 LLM training 전용 (`--params --bsz --seq --n-layer --d-model`). M5 1904-bf hybrid DFT 메모리/시간 산정에 못 씀 → **RFC 091 (preflight v2 DFT/HPC) witness**. DFT 도 닫힌형 추산 가능 (basis-fn 수 · method scaling N³~N⁴ · hybrid vs pure) → rent 전 GPU vs CPU-HPC 판단 자동화.
- [ ] **workload-aware sizing 부재** — NWChem hybrid DFT(exact exchange) = **CPU-bound** → `rent --gpu <type>` 만 있고 `--vcpu/--ram` 필터 없음. CPU-HPC 워크로드(@D d7 "batch → Vast.ai CPU")는 vCPU/RAM 기준 선택 필요. (이번엔 H100 80-core 가 우연히 적합했으나 GPU 단가로 골라짐 — 비용 비효율 risk)
- [ ] **rent 이미지 sshd 필수** — minimal 이미지(`miniconda3` 등) sshd 미기동 → rent 침묵 실패. `nvidia/cuda:*-devel-ubuntu22.04` 성공. `vast_create` 가 `--ssh --direct` 만(onstart 없음) → rent 가 sshd-onstart 주입 또는 이미지 sshd 검증/경고 권장.
- [ ] **rent `--max-price` client filter 부재** (vast.hexa TODO) — 비용 상한 가드 없음 = 실비 폭주 risk. on-demand offer dph 상한 플래그.
→ cross-ref RFC 088 (P-series provisioning) · RFC 091 (preflight DFT/HPC). M5 c01 (Ce₆O₁₂+azo PBE0/CRENBL-ECP) 실행 검증 = `rent`/`exec`/`copy-to`/`copy-from` 체인 정상 동작 확인 ✅.

## 2026-05-25T00:50Z — [정정] 위 "빌드 회귀" 보고 RETRACT — worktree 아티팩트였음 — RESOLVED #866

직전 엔트리(00:25Z)의 "빌드 회귀" 진단은 **오진**이었음 — origin/main 은 정상. 실제 원인: `hexa build` 의 use-확장(module-loader)이 **정식 repo 루트 `~/core/hexa-lang` 에서만** 작동하고, `/tmp` 의 detached git worktree 에선 건너뜀.
- [x] 정식 루트에서 `bash tool/build_hexa_verify.sh` → `[1/2]` 가 `hexa_build_expanded.<ts>.tmp.hexa`(use-inline 확장본) 컴파일 → **빌드·링크 성공**
- [x] `/tmp` worktree 에선 `[1/2]` 가 `verify_cli.hexa` 를 **직접** 컴파일(확장 생략) → `static_atlas` 등 미정의 링크 실패 (= 00:25Z 가 본 증상)
- [x] `cycles_to_target`/`compound_coverage` (PR #803) 정식 루트 빌드 → `hexa verify --expr cycles_to_target 0.12 0.1 19` = **🟢 SUPPORTED-NUMERICAL** (TTR-MN timeline 5/5 · 대조 18→🔴 FALSIFIED)
- [x] **RESOLVED on main by #866** (`fix(hexa/build): install_dir_from_argv0 — PATH-resolve bare-basename argv[0] before realpath (worktree shadow)`). 진짜 루트코즈는 `.git`-file 탐지 아니라 **argv[0] basename CWD shadow**: ~/.hx/bin/hexa shim 이 `exec -a hexa` 라 inner driver 의 argv[0] = bare `hexa`. POSIX `realpath hexa` 는 CWD 먼저 탐색 → /tmp worktree 가 (repo 에서 commit 된) ./hexa shim 파일을 들고있어 → realpath = /tmp/<wt>/hexa → install_dir = /tmp/<wt> → no `build/hexa_module_loader` → `[flat] warn` + skip. fix: argv[0] 에 슬래시 없으면 (= bare basename) `command -v` 로 PATH 우선 해석, realpath 는 fallback. e2e 검증 (replay /tmp/hexa-wtest-2026-05-25): pre `[flat] warn: ... not found` → post `[flat] module_loader → /tmp/.hexa-runtime/hexa_build_expanded.<ts>.tmp.hexa`.

## 2026-05-25T00:25Z — [RETRACTED · 아래 00:50Z 정정 참조] `hexa verify` sub-binary 빌드 회귀: 다중모듈 use 링크 누락 (from: demiurge TTR-MN)

clean origin/main(`8f31d339` #801)에서 `bash tool/build_hexa_verify.sh` 가 link 단계 실패 — undefined symbols `static_atlas`·`sigma_k`·`mobius`·`jacobi_symbol`·`kronecker_symbol`·`isotropy_lcm`·`recompute`·`recompute2`·`read_file_safe`·`write_file_safe`. 이들은 `tool/verify_cli.hexa` 의 `use "compiler/atlas/static_index"` + `use "self/stdlib/fs"` 가 제공하는 정의. codegen(`hexa_v2 tool/verify_cli.hexa out.c`)은 OK 지만 .c(127KB)에 해당 정의 미flatten → `hexa build` 의 모듈 .o 링크 목록에서 누락.
- [ ] `hexa build` 다중모듈 link 목록이 `use compiler/atlas/*` + `self/stdlib/*` 의존 .o 를 포함하도록 복구
- [ ] 메모리 cap 아님 확인됨 — `HEXA_MEM_CAP_MB=49152` 직접 `hexa_v2` 호출에도 .c 미flatten · `build_hexa_verify.sh` 주석의 16384 권고는 무효
- [ ] 회귀 시점 후보 = #790 (abolish inbox → rehome+rewire · `verify_cli.hexa` 를 마지막 수정) · 미확정
- [ ] 영향 범위: `hexa verify --expr <fn>` 전체(welch_t_crit 등 기존 fn 포함) 신규 빌드 불가 — main repo 17:14 빌드 바이너리(pre-#790 계보)만 동작
- 우회(현): 독립 `.hexa` 를 `hexa build` 네이티브 컴파일하면 함수 단위 검증 가능 (verdict formatter 만 막힘). 동반 PR 의 `cycles_to_target`/`compound_coverage` 는 이 경로로 TTR-MN (1-x)^N timeline **5/5 PASS** 확인 (x→N = 0.047→48·0.08→28·0.12→19·0.15→15·0.20→11).

## 2026-05-24T13:35Z — hexa cloud pod 생성(provision) verb 부재 (from: demiurge RTSC)

dispatch만 wrap(run/nohup/poll/copy)·lifecycle(생성/teardown/조회) 미wrap. RTSC SrAuH₃ GPU 가속 시도 중 발견 — vast pod를 hexa cloud로 만들 수 없고 raw `vastai`는 cloud-guard 차단(@D g8) → 사람 수동 web UI 외 clean 경로 0. 진단 verb(list/status/orphans)는 runpodctl 전용 = vast surface 0.
- [ ] `hexa cloud up <provider> --gpu <t> [--image --disk --owner --max-price]` + `down <id>` 생성/teardown verb (provider ∈ runpod|vast · vast REST **wrapped** = raw 금지 해소)
- [ ] list/status/orphans provider-generic화 (현 runpodctl 전용 → vast 포함)
- [ ] `up`이 pod registry append (`hexa-cloud-pod-registry-tracking` lockstep — 발사시점 자동기록 → orphan 구조적 방지)
- [ ] 근거: g8이 "모든 rented-GPU = hexa cloud" 약속하나 생성만 빠져 반쪽. 채우면 에이전트 자율 GPU + @D d7 h3o SSCHA(≥20원자)·RTSC SrAuH₃ 가속 가능

→ **closed-as-tracked (g48 · 2026-05-24)**: 본 갭은 신규 아님 — provisioning verb는 `archive/patches/archive/hexa-cloud-preflight-stub-and-provisioning-gap-2026-05-24.md` **gap#2**(→ RFC 088 P-series), DFT/HPC 워크로드 preflight는 **RFC 091**(`rfc_091_hexa_cloud_preflight_v2_dft_hpc`)로 이미 추적. preflight 절반은 PR #703(`stdlib/cloud/preflight.hexa`, LLM axis)로 구현됨. 본 entry의 추가 가치 = (a) **vast** provider 강조(기존 추적은 runpod 중심) + (b) RTSC **SrAuH₃**(M8 게이트 병목)라는 concrete DFT-HPC use-case → **RFC 091에 witness 추가** + provisioning **vast arm**을 RFC 088 P-series에 반영 권고. cross-repo handoff = 수신·라우팅 완료.

