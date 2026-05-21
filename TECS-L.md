# TECS-L.md — `hexa loop` DFS+LLM 모드 이식 계획

> archive-TECS-L (dancinlab/archive-TECS-L) 의 발견·흡수 전략을 `hexa loop`
> (RFC 065 self-growing atlas) 에 옵션으로 이식하기 위한 SSOT.
> 작성 2026-05-22 · 브랜치 후보 `rfc-080-hexa-loop-dfs`

---

## 0. 발화 맥락

사용자 요청 chain:
1. `hexa loop` 개선 필요
2. LLM 개입 옵션 필요 — TECS-L 처럼 LLM 과 동반 진행하는 모드
3. TECS-L 의 "새 수학 발견·흡수" 방식 전수조사
4. "타고타고 내려가는" 전략 = **DFS** 확정
5. 업데이트 계획 브레인스토밍 고갈까지 → 본 문서

---

## 1. archive-TECS-L 발견·흡수 전략 카탈로그 (10개)

### Top-level engines

| # | 전략 | 파일 | 입력 → 출력 | 메커니즘 |
|---|------|------|-------------|----------|
| 1 | **DFS Engine** | `dfs_engine.py` | n=6 상수 + 타겟 → cross-island matches | tecsrs Rust 코어, 깊이 제한 재귀, 오차 임계 필터 |
| 2 | **Convergence Engine** | `convergence_engine.py` | 8 도메인 ×~80 상수 → 수렴점 클러스터 | S1 (Open Search) / S2 (Pair Scan) / S3 (Target Backtrack) 3 부전략 + 이진 연산 조합 |
| 3 | **Quantum Formula Engine** | `quantum_formula_engine.py` | 18 proj × 9 quantum → 수학 타겟 매칭 | depth 2-3 조합 + Texas Sharpshooter p-value |
| 4 | **Perfect Number Engine** | `perfect_number_engine.py` | n∈{6,28,496,8128} σ/τ/φ → 물리상수 표현식 | 완벽수별 "atom 풀" + n-depth 조합 |
| 5 | **Proof Engine** | `proof_engine.py` | 발견 수식 → Tier 0-3 등급 | rigorous_steps vs weak_steps + Tier 승격 규칙 |
| 6 | **Congruence Chain Engine** | `congruence_chain_engine.py` | N=1..100 + Γ₀(N) 불변량 → genus-σ 관계식 | Modular form + Moonshine 탐색 |

### math/ 하위 sub-DFS

| # | 전략 | 파일 | 타겟 |
|---|------|------|------|
| 7 | **DFS-Dedekind ψ Discrepancy** | `math/dfs_dedekind_psi_discrepancy.py` | n=6/28 유일성 (D(n)=σφ−n·τ) |
| 8 | **DFS-n6 Special Sequences** | `math/dfs_n6_special_sequences.py` | Catalan / Bell / Stirling / Ramanujan / Fibonacci 매칭 |
| 9 | **Coding Lattice DFS** | `math/coding_lattice_dfs.py` | Hamming / Golay / E₆ / E₈ / Leech |
| 10 | **Bridge Explorer** | `math/bridge_explorer.py` | 도메인 간 다리 (Shannon ↔ j-invariant 등) |

### 흡수 루프 (discovery_loop.py)

```
DFS → Convergence → Quantum → Perfect → Verify → Grow → Paper → Repeat
   ↓
   results/loop/discoveries.jsonl  (JSON-Lines 누적)
   docs/hypotheses/                (가설 카탈로그, 2,711 건)
   zenodo/                         (논문 49 건 export)
```

---

## 2. 현재 `hexa loop` 상태 (Phase B-3)

- SSOT: `stdlib/loop/cycle.hexa`
- 8-stage cycle: SCAN → LENS → DEDUP → GATE → FIRE → DRAFT → AUDIT → EXHAUST
- 36 lens / 8 family (empty_space · paradigm_shift · cross_pollinate ·
  counterexample_mine · invariant_stress · scale_extrapolate ·
  constraint_flip · falsify_self · unfold)
- emit 경로: `inbox/atlas_candidates/<slug>.md` (PR-only, embedded.gen 절대
  미수정)
- LLM 호출 0 건 — 모두 hexa-native lens

---

## 3. 브레인스토밍 18 축 (전수조사)

### 축 1 — CLI 표면
- 1a `--dfs --depth N --beam K --llm-cmd <cmd>` (직교 분리)
- 1b `--option` alias = `--dfs --depth 3 --beam 2 --llm-cmd $HEXA_LLM_CMD`
- 1c `--mode dfs` (mode 도입 — 향후 `--mode converge` 등)
- 1d 두 verb 분리: `hexa loop` vs `hexa loop-dfs`
- **결정**: 1a + 1b alias. 1d 는 verb 폭증.

### 축 2 — LLM 호출 메커니즘
- 2a `exec_capture("claude -p ...")` — claude CLI 의존
- 2b Anthropic SDK 직접 (stdlib/cloud HTTP) — API key 필요
- 2c **pluggable** `--llm-cmd <any-shell-cmd>` — stdin=prompt, stdout=response
- 2d MCP-style RPC (overkill)
- **결정**: 2c (verb-binary 정신 · vendor lock-in 회피 · claude/codex/local
  llama 동등 지원)

### 축 3 — Output contract
- 3a JSON
- 3b **markdown front-matter** (현 emit 포맷과 동형)
- 3c hexa struct serialize
- **결정**: 3b — input/output mirror, LLM 학습 분포에 fit

### 축 4 — DFS 형태
- 4a pure DFS
- 4b **beam search** (depth 마다 top-K)
- 4c best-first
- 4d random restart
- 4e iterative deepening
- **결정**: 4b beam K=2-3 (TECS-L `dfs_engine.py` 도 사실상 branch + depth limit)

### 축 5 — Pruning gate (5 단)
1. cite missing → drop
2. dedup against `chain.jsonl` (현 cooldown)
3. F-vector classify (현행)
4. fire_needed at depth>0 → defer (재귀 차단)
5. novelty score: cite 가 atlas 변두리 → 가산, hub → 감산
- **결정**: 5 단 모두 (LLM 호출은 이미 prune 통과한 것만 — cheap-first)

### 축 6 — 비용 cap (3-way AND)
- 6a `--llm-budget <USD>` (token × price)
- 6b `--llm-calls <N>` (hard count)
- 6c `--llm-time <secs>` (wall)
- **결정**: 3 개 모두 AND-gate, whichever hits first

### 축 7 — State 통합
- `state/loop/dfs_frontier.jsonl` (depth 간 frontier persist)
- `state/loop/llm_calls.jsonl` (call audit: prompt SHA · model · tokens · cost · ms)
- chain.jsonl 확장: `parent_slug` / `depth` / `llm_model` / `cost_usd`
- `state/loop/llm_drops.jsonl` (verify 에서 drop 된 출력 — debug)

### 축 8 — Inbox layout
- 8a flat `inbox/atlas_candidates/<slug>.md` (현행 · collision risk)
- 8b **nested** `inbox/atlas_candidates/dfs_<parent>/<child>.md` (DFS tree → FS tree)
- 8c flat + prefix `dfs_d<depth>_<parent>__<child>.md`
- **결정**: 8b — PR review 시 sub-tree 단위로 묶임

### 축 9 — Prompt scaffold
- 9a parent candidate full md
- 9b + cite 노드 raw body (`compiler/atlas/by_kind/p.gen.hexa` lookup)
- 9c + nearest 5 atlas neighbor (cite-graph) — 미구현, skip
- 9d + lens family hint
- 9e + 출력 규약 (markdown · cite required · English only · K children)
- 9f + 거버넌스 (CLAUDE.md @D · English only · @V `tape`)
- **결정**: 9a/b/d/e 본문, 9f 는 system prompt 한 번. 9c 는 follow-up.

### 축 10 — LLM output verify
- 10a markdown front-matter parse (`- cite:` `- fire_needed:`)
- 10b cite 비어있음 → drop
- 10c cite ID 가 ATLAS_P / L node 에 실재? (hallucination gate)
- 10d fire_needed parse 실패 → default false (관대)
- 10e proposed body < 50 char → drop (trivial)
- 10f Korean glyph 검출 → drop (English-only 룰)
- 10g retry 금지 (drop 1 회, 다음 frontier)
- **결정**: 10a/b/c/e/f/g 강제 · 10d 관대

### 축 11 — Lens × LLM 조합
- 11a 모든 lens (cost 폭주)
- 11b LLM 효과 큰 family: `empty_space` · `cross_pollinate` ·
  `counterexample_mine` · `paradigm_shift`
- 11c `--llm-families <a,b,c>` user-select, default = 11b
- **결정**: 11c default = 11b

### 축 12 — TECS-L → hexa loop 매핑
| TECS-L | hexa loop | RFC |
|--------|-----------|-----|
| DFS Engine | `--dfs` 본 RFC | **RFC 080** |
| Convergence Engine | `--converge` (다중 cite 노드 수렴) | follow-up |
| Bridge Explorer | `cross_pollinate` lens LLM-enhanced | follow-up |
| Texas Sharpshooter | `falsify_self` lens p-value | follow-up |
| Proof Tier 0-3 | cite-chain depth 등급 | follow-up |
| Quantum Formula | `scale_extrapolate` lens 강화 | follow-up |
| Perfect Number | atlas P-node 핵심 노드 추출 | follow-up |
| Congruence Chain | invariant_stress lens 강화 | follow-up |

### 축 13 — Resumability
- 13a `--resume` (이미 help 에 있음, 미배선)
- 13b `state/loop/dfs_frontier.jsonl` 읽고 마지막 depth 부터
- 13c SIGINT → 현 frontier flush 후 종료 (graceful)

### 축 14 — Cache (HXC sidecar, RFC 066 패턴)
- `dist/llm_cache.hxc`
- key = SHA256(prompt + model_name + temperature)
- value = response + timestamp + token_usage + cost
- `--no-cache` opt-out
- 동일 cycle 재실행 = $0 cache-hit

### 축 15 — Telemetry
- per-call: input/output tokens · wall ms · model · cost USD · prompt SHA
- per-cycle: total cost · children emitted · prune count · frontier remaining · cache hit ratio
- summary line: `[loop:dfs] depth=3 beam=2 calls=14 cost=$0.21 emitted=8 dropped=6 cached=4`

### 축 16 — Determinism
- temperature=0 (지원시)
- 모델명+버전 chain.jsonl 기록
- cache hit 보장 byte-eq replay
- `--seed <N>` (모델 미지원시 cache key 에만 영향)

### 축 17 — Governance (AGENTS.tape)
- @D `g_atlas_binary_builtin` — PR-only, embedded.gen 직접 수정 금지
- @D `g6` — cite enforced (축 10c verify 가 강제)
- @D `g_interp_deprecated` — compiled-path only
- @D `g_plan_consolidation` — `compiler/PLAN.md` 에 cycle 기록
- **신규 @D `g_llm_pluggable`** — LLM 모드 opt-in only · 비용 cap 의무 ·
  출력 verify 의무 · 한국어 출력 거부 · embedded.gen 자동수정 금지

### 축 18 — Backward compatibility
- bare `hexa loop` → 현행 그대로 (LLM 0 건)
- `--dfs` 단독 (no `--llm-cmd`) → error
- 모든 신규 flag default off
- `--option` alias 는 `$HEXA_LLM_CMD` env 의무

---

## 4. Risks & 완화 (13 건)

| # | 위험 | 완화 |
|---|------|------|
| R1 | 비용 폭주 | 3-way AND budget cap |
| R2 | Hallucinated cite | 축 10c verify · drop 1 회 retry 금지 |
| R3 | Determinism 손실 | temperature=0 + cache + model 기록 |
| R4 | Worktree race | main worktree 단일 실행, parallel 금지 ([[feedback_subagent_worktree_leak_pattern]]) |
| R5 | 한국어 출력 누락 | 축 10f English-only verify ([[project_hexa_lang_english_only]]) |
| R6 | runtime.c silent-wipe | `stdlib/loop/cycle.hexa` 만 수정 · runtime.c 절대 미접촉 ([[feedback_runtime_c_deploy_regen_wipe]]) |
| R7 | HEXA_MODULE_LOADER 누락 | build doc 명시 ([[reference_hexa_module_loader_env_2026_05_20]]) |
| R8 | exec_argv 미배선 | `exec_capture` 만 사용 ([[reference_hexa_exec_argv_not_codegen_wired]]) |
| R9 | 출력 schema 위반 | drop+log, retry 금지 |
| R10 | 자율 무한 cycle | cooldown + EXHAUST 통과 의무 |
| R11 | embedded.gen 자동 수정 유혹 | governance gate + write_text 경로 inbox/* 외 금지 (코드 enforce) |
| R12 | shell injection | prompt 는 stdin/file 로만, argv 비전달 |
| R13 | 32k+ prompt → 모델 거부 | parent+cite 합 16k char cap, cite raw 우선 자름 |

---

## 5. Plan — Phase A → J

브랜치: `rfc-080-hexa-loop-dfs` (현 `dfflibmap-sky130-reset-flop-variants-2026-05-22` 위 stacked)
SSOT: `inbox/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md`
바이너리 promote: 모든 Phase pass 후 자체빌드 + ceremony, 단일 commit

| Phase | 작업 | 산출 | Gate |
|-------|------|------|------|
| **A** CLI scaffold | flag 파싱 (no-op stage): `--dfs --depth N --beam K --llm-cmd --llm-budget --llm-calls --llm-time --llm-families --resume --no-cache --option --allow-llm` | `stdlib/loop/cycle.hexa` arg block 확장 · `cmd_loop_help()` 갱신 · VERSION 0.0.1→0.1.0 | `hexa loop --dfs --depth 2 --llm-cmd echo` 가 flag print 후 종료 |
| **B** LLM 호출 primitive | `dfs_llm_invoke(prompt, cmd) -> string` via `exec_capture` · prompt file dump 후 `< file` redirect | `stdlib/loop/llm.hexa` 신규 (or cycle.hexa inline) | stub `cat fixture.md` → markdown 회수 |
| **C** DFS engine | `dfs_iter(frontier, depth, max_depth, beam)` 재귀 · prompt build · parse children · beam top-K enqueue | `stdlib/loop/dfs.hexa` 신규 | stub depth=2 beam=2 → 4 child emit, FS tree 검증 |
| **D** Verify gate | markdown parse · cite cross-check ATLAS_P/L · English-only · trivial filter · drop log | verify fn + `state/loop/llm_drops.jsonl` | 한국어/missing cite/empty body fixture → 모두 drop |
| **E** Budget guard | 3-way AND counter · short-circuit · frontier flush | budget struct + check fn | `--llm-calls 2` → 정확히 2 call |
| **F** State + resume | `state/loop/dfs_frontier.jsonl` r/w · `--resume` 배선 · chain.jsonl 확장 | state I/O fn in `stdlib/loop/state.hexa` | run1 (--llm-calls 1) → run2 (--resume) → frontier 0 |
| **G** HXC cache | `dist/llm_cache.hxc` sidecar · SHA256 key · `--no-cache` | cache fn + RFC 066 포맷 | 동일 prompt 2 회 → 2 번째 cache hit ($0) |
| **H** Test infra | `tests/loop/dfs_*.hexa` 자체완결 (stub LLM cmd = `bash -c 'cat fixture'`) · 5 시나리오 | tests + `tool/run_dfs_tests.sh` | 5/5 PASS · `hexa parse` clean · 자체빌드 clean |
| **I** RFC + governance | `inbox/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md` · AGENTS.tape `@D g_llm_pluggable` · `cmd_loop_help()` 최종판 · `compiler/PLAN.md` entry | docs | PR set (skill `gh-stack`) |
| **J** Real-LLM oracle | `--allow-llm` gate → 진짜 claude CLI 1 회 호출 · cost 측정 · drop ratio | 결과 표 `compiler/PLAN.md` | cost ≤ $0.05 · ≥1 child verify 통과 · rerun cache hit |

---

## 6. 결정 요약

- **Mechanism**: pluggable `--llm-cmd <shell-cmd>` (축 2c)
- **Form**: beam search K=2-3 (축 4b)
- **Output**: markdown front-matter (축 3b)
- **Verify**: 6 단 cite-required gate (축 10)
- **Budget**: 3-way AND (USD/calls/time)
- **Cache**: HXC sidecar SHA256
- **Governance**: 신규 `@D g_llm_pluggable` · embedded.gen 미수정 · English-only · PR-only
- **Backward compat**: bare `hexa loop` 무변동, 모든 신규 flag opt-in
- **Version**: 0.0.1 → 0.1.0 ("DFS+LLM Phase 1")

---

## 7. 비범위 (follow-up RFC)

- Convergence Engine 포팅 (`--converge`)
- Bridge Explorer 강화 (`cross_pollinate` LLM 모드)
- Texas Sharpshooter p-value (`falsify_self` 강화)
- Proof Tier 0-3 등급 (cite-chain depth)
- Quantum Formula → `scale_extrapolate` 강화
- Perfect Number 분해 → P-node 추출
- Congruence Chain → `invariant_stress` 강화
- Multi-LLM ensemble quorum
- 병렬 LLM 호출 (rate-limited)
- Nearest-atlas-neighbor cite graph (atlas graph 인덱스 신규)
- `exec_argv` codegen wiring ([[reference_hexa_exec_argv_not_codegen_wired]])

---

## 8. 다음 행동

1. 본 문서 (TECS-L.md) commit
2. 사용자 승인 or redirect 대기
3. 승인시 Phase A 진입 (`stdlib/loop/cycle.hexa` arg block 확장)
