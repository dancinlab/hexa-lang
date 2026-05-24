# INBOX — log

Append-only history sister of `INBOX.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

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
- [ ] **배포 갭 (consumer action)**: 배포된 컴파일러(`~/.hx/bin` · repo dir 이 `chore/abolish-inbox-folder` = pre-#829 계보)는 아직 버그 잔존 → `_paper.hexa` 증상은 컴파일러를 #829+ 로 갱신해야 사라짐. `_paper.hexa` 쪽 rename 우회는 하지 않음(@user). hexa-lang 코어 fix 는 완료 — 남은 건 배포 refresh 뿐.

## 2026-05-25T03:00Z — codegen: 파라미터명이 호출부 struct 필드명과 같으면 미스컴파일

- [ ] `tool/atlas_cli.hexa` 작업 중 발견. `fn f(raw: string)`를 `f(ev.raw)`로 호출하면 함수 body의 `raw`가 호출부 인자값(394자 문자열)이 아니라 `"x"`(len 1)로 바인딩됨 — 파라미터명이 호출부 struct 필드 접근명(`raw`)과 충돌하는 codegen aliasing. `node_raw`로 rename하면 정상. 재현: 3-string-param fn에 `.<param명과 동일한>` 필드접근 인자 전달 → 빌드는 통과하나 런타임에 잘못된 값. 임시회피=param rename, 근본수정=codegen name-resolution (compiler/codegen 영역).

## 2026-05-25T02:10Z — hexa cloud 개선 4건 (from: demiurge TTR-MN M5 cluster DFT 실전)

M5 cluster DFT (vast `rent` H100 + NWChem PBE0) 실전 중 발견. 전부 우회 가능했으나 SSOT 기록:
- [ ] **preflight DFT/MD 축 부재** — 현재 `preflight`는 LLM training 전용 (`--params --bsz --seq --n-layer --d-model`). M5 1904-bf hybrid DFT 메모리/시간 산정에 못 씀 → **RFC 091 (preflight v2 DFT/HPC) witness**. DFT 도 닫힌형 추산 가능 (basis-fn 수 · method scaling N³~N⁴ · hybrid vs pure) → rent 전 GPU vs CPU-HPC 판단 자동화.
- [ ] **workload-aware sizing 부재** — NWChem hybrid DFT(exact exchange) = **CPU-bound** → `rent --gpu <type>` 만 있고 `--vcpu/--ram` 필터 없음. CPU-HPC 워크로드(@D d7 "batch → Vast.ai CPU")는 vCPU/RAM 기준 선택 필요. (이번엔 H100 80-core 가 우연히 적합했으나 GPU 단가로 골라짐 — 비용 비효율 risk)
- [ ] **rent 이미지 sshd 필수** — minimal 이미지(`miniconda3` 등) sshd 미기동 → rent 침묵 실패. `nvidia/cuda:*-devel-ubuntu22.04` 성공. `vast_create` 가 `--ssh --direct` 만(onstart 없음) → rent 가 sshd-onstart 주입 또는 이미지 sshd 검증/경고 권장.
- [ ] **rent `--max-price` client filter 부재** (vast.hexa TODO) — 비용 상한 가드 없음 = 실비 폭주 risk. on-demand offer dph 상한 플래그.
→ cross-ref RFC 088 (P-series provisioning) · RFC 091 (preflight DFT/HPC). M5 c01 (Ce₆O₁₂+azo PBE0/CRENBL-ECP) 실행 검증 = `rent`/`exec`/`copy-to`/`copy-from` 체인 정상 동작 확인 ✅.

## 2026-05-25T00:50Z — [정정] 위 "빌드 회귀" 보고 RETRACT — worktree 아티팩트였음 (from: demiurge TTR-MN)

직전 엔트리(00:25Z)의 "빌드 회귀" 진단은 **오진**이었음 — origin/main 은 정상. 실제 원인: `hexa build` 의 use-확장(module-loader)이 **정식 repo 루트 `~/core/hexa-lang` 에서만** 작동하고, `/tmp` 의 detached git worktree 에선 건너뜀.
- [x] 정식 루트에서 `bash tool/build_hexa_verify.sh` → `[1/2]` 가 `hexa_build_expanded.<ts>.tmp.hexa`(use-inline 확장본) 컴파일 → **빌드·링크 성공**
- [x] `/tmp` worktree 에선 `[1/2]` 가 `verify_cli.hexa` 를 **직접** 컴파일(확장 생략) → `static_atlas` 등 미정의 링크 실패 (= 00:25Z 가 본 증상)
- [x] `cycles_to_target`/`compound_coverage` (PR #803) 정식 루트 빌드 → `hexa verify --expr cycles_to_target 0.12 0.1 19` = **🟢 SUPPORTED-NUMERICAL** (TTR-MN timeline 5/5 · 대조 18→🔴 FALSIFIED)
- [ ] (선택) `hexa build` 가 worktree(`.git` 가 dir 아닌 file)에서도 use-확장 하도록 project-root 탐지 보강 — 추정 원인, 미확정 · low-pri gotcha

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

