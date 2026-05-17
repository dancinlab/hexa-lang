# RFC-046 — `sim-universe` 흡수 (`stdlib/sim_universe/`)

- **상태**: **Phase A scaffold landed** (2026-05-16) — README + CLI + governance + archive; substrate/experiment code migration → RFC 046-A / RFC 046-B
- **작성일**: 2026-05-16
- **선행**: 헌법 v2 (5 룰) + RFC 044 (qrng absorption pattern)
- **흡수 시리즈 #3/3**: RFC 044 (qrng ✅) → RFC 045 (qmirror ⏸ upgrade 대기) → **RFC 046 (sim-universe, Phase A)**
- **사용자 결정 (2026-05-16)**: nexus 식 archive 전환 + README 보존 + 별도 CLI 폐기 후 hexa CLI 통합
- **영향 영역**: `stdlib/sim_universe/` (신규 scaffold) · `self/main.hexa` (sim-universe dispatch + cmd_help) · `AGENTS.tape` (§0 sim_universe_stack + l1 + @D ×2 + @F + @X)

---

## 1. 동기

`~/core/sim-universe/` v1.1.0 — 32,419 LoC `.hexa` across 26 module directories — 은 hexa-lang 의 stdlib 으로 흡수 대상 (헌법 v2 룰 2 + 룰 3). RFC 044 (qrng) 와 동일 패턴 적용.

스코프 차이: qrng 는 4,383 LoC 단일 패키지였지만 sim-universe 는 32k LoC 26-module ensemble. 한 세션 풀 마이그레이션은 비현실적. **Phase A scaffold + Phase B/C 코드 마이그레이션 분할**:

- **Phase A (본 RFC)**: scaffold — README · CLI dispatcher · governance · archive 묘비. 즉시 land.
- **Phase B (RFC 046-A)**: 10 substrate 모듈 코드 마이그레이션 (~14k LoC)
- **Phase C (RFC 046-B)**: 16 experiments 코드 마이그레이션 (~14k LoC) + per-experiment tests

이 분할로 본 RFC 는 (a) CLI 표면 즉시 작동, (b) 묘비 freeze 즉시 완료, (c) 후속 코드 마이그레이션의 baseline 제공.

## 2. 헌법 v2 룰 매핑

| 룰 | 본 RFC 처리 | Phase |
|---|---|---|
| 1 (rodata 시드) | 비해당 (sim-universe = 응용/도구) | — |
| 2 (알고리즘 흡수) | 26 modules → `stdlib/sim_universe/` + `experiments/` | A: scaffold · B/C: code |
| 3 (메타 frozen) | AGENTS.tape · README · CHANGELOG · CITATION · DESIGN_IDEAS · FALSE_VACUUM · STARK_FRAGMENTATION · MODULE/ · 26 module dirs → `~/core/archive_sim-universe/` 묘비 | A ✅ |
| 4 (외부 자원 δ) | `ouroboros_qrng` → consumes `stdlib/qrng/` (RFC 044). qpu_bridge ANU noise adapter. | A: governance · B: code |
| 5 (overlay) | drill round 결과 누적 — bostrom_test pre-registered results 가 잠재 후보 | C 검토 |

## 3. 흡수 명세

### 3.1 Phase A (본 RFC, landed)

```
stdlib/sim_universe/
├── README.md                              # adapted from upstream 601-line README
└── sim_universe.hexa                      # CLI dispatcher (hexa sim-universe target)

self/main.hexa
└── +`else if sub == "sim-universe"` dispatch + cmd_help STDLIB CLI 섹션

AGENTS.tape
├── +§0 @N sim_universe_stack
├── @L l1 +stdlib/sim_universe/ entry
├── +@D g_sim_universe_honest_scope
├── +@D g_sim_universe_qrng_consumer
├── +@F f_sim_universe_lattice_qcd_claim
└── +@X x_archive_sim_universe (DOI 10.5281/zenodo.20102970)

~/core/archive_sim-universe/                 # frozen 묘비, chmod a-w, 142 files / 18MB
├── ABSORBED.md                              # NEW pointer
├── AGENTS.tape · README.md · CHANGELOG · CITATION · LICENSE · ...
├── DESIGN_IDEAS_2026_05_12.md · FALSE_VACUUM.md · STARK_FRAGMENTATION.md
├── hexa.toml · install.hexa · .gitignore
├── cli/sim-universe.hexa
├── docs/ · MODULE/ · examples/
└── 26 module directories (anu_time/ · multiverse/ · ... · weave/) 코드 포함
```

### 3.2 Phase B (RFC 046-A — substrate code, ~14k LoC)

```
stdlib/sim_universe/
├── anu_time/                              # 5,881 LoC, 12 files
│   ├── mini_world.hexa
│   ├── anu_clock.hexa
│   ├── lorentz_metric.hexa
│   ├── field_action.hexa
│   ├── topology_universe.hexa
│   ├── quantum_universe.hexa
│   ├── universe.hexa
│   ├── universe_propagation.hexa
│   ├── universe_ensemble.hexa
│   ├── universe_pipeline.hexa
│   ├── scale_universe.hexa
│   ├── empirical_anchor.hexa
│   ├── empirical_anchor_v2.hexa
│   └── analyze.hexa
├── multiverse/                            # 4,181 LoC, 11 files
├── qpu_bridge/                            # 441 LoC, 2 files
├── sim_agent/                             # 492 LoC, registry + router (lib entry)
├── ouroboros_qrng/                        # 862 LoC; use "stdlib/qrng/router" etc.
├── godel_q/                               # 758 LoC
├── bostrom_test/                          # 235 LoC
├── sr_harness/                            # 800 LoC
├── atlas_anu_corr/                        # 5 files
└── anu_stream/                            # 3 files
```

Phase B 작업:
- 각 substrate 모듈 → `stdlib/sim_universe/<name>/` 으로 relocate
- 중복 struct (만약 있으면) → 공유 helper module `stdlib/sim_universe/source.hexa` (qrng 패턴)
- `ouroboros_qrng` 의 ANU 4-tier fallback → `use "stdlib/qrng/router"` 위임 (RFC 044 consumer)
- `sim_universe.hexa` dispatcher: substrate subcommand 들의 `cmd_deferred` 를 실제 호출로 교체

### 3.3 Phase C (RFC 046-B — experiments code, ~14k LoC + tests)

```
stdlib/sim_universe/experiments/
├── fvd/                                   # 1,338 LoC — Chao 2026
├── stark_fragmentation/                   # 1,212 LoC — Wang 2024
├── quantum_darwinism/                     # 1,282 LoC — Zhu 2025
├── ca_qm/                                 # 1,142 LoC — Elze + van Berkel
├── supremacy_frontier/                    # 1,272 LoC — Morvan 2024
├── mbs_revival/                           # 869 LoC — Xiang 2024
├── fock_prethermal_dtc/                   # 771 LoC — Bao 2025
├── z2_gauge_prethermal/                   # 804 LoC — Hayata-Hidaka 2024
├── preheating_analog/                     # 615 LoC — Gondret 2025
├── multipolar_prethermal/                 # 1,176 LoC — Liu 2025
├── surface_code/                          # 835 LoC — Acharya 2024
├── ssh_topology/                          # 693 LoC — SSH 1979
├── hofstadter/                            # 823 LoC — Hofstadter 1976
├── dqpt_loschmidt/                        # 684 LoC — Heyl 2013
└── wdw_minisuperspace/                    # 889 LoC — Basilakos 2025

stdlib/test/
└── test_sim_universe_*.hexa               # per-module selftest sentinels
```

Phase C 작업:
- 16 experiments 표준 program-style 보존 (각자 main() + sentinel; 라이브러리화 NOT 필요 — 응용은 standalone)
- 각 experiment 의 per-module honest scope caveat 보존 (NOT decoherent · NOT lab device · NOT L→∞)
- `sim_universe.hexa` dispatcher: 16 experiment subcommand 들의 `cmd_deferred` 를 `cmd_run(experiments/<name>/<name>.hexa, args)` 으로 교체

## 4. CLI 통합 (별도 `tool/hexa_sim_universe/` 폐기)

원본 `~/core/sim-universe/cli/sim-universe.hexa` (~580 LoC subprocess + sentinel-parse 아키텍처). 본 RFC 는 **hexa main CLI 통합**:

- `stdlib/sim_universe/sim_universe.hexa` — dispatcher (Phase A scaffold; subcommand stubs return "deferred to RFC 046-A/B")
- `self/main.hexa` + `else if sub == "sim-universe"` 분기 — `cmd_run(stdlib/sim_universe/sim_universe.hexa, args[3..])` 위임
- 별도 `tool/hexa_sim_universe/` 디렉토리 없음

호출 패턴 (오늘 작동):

```sh
hexa sim-universe                           # default = status (Phase A)
hexa sim-universe status                    # module inventory + tier table
hexa sim-universe --help                    # full subcommand reference
hexa sim-universe --version                 # 1.1.0
```

호출 패턴 (Phase B/C 후 작동):

```sh
hexa sim-universe selftest                  # Tier-A smoke pass
hexa sim-universe anu                       # τ-clock mini_world
hexa sim-universe multiverse                # interferometer + KS
hexa sim-universe qrng                      # ouroboros QRNG
hexa sim-universe fvd                       # FVD experiment
hexa sim-universe fvd --lindblad --selftest # FVD GKSL Lindblad mode
# ... 16 experiment subcommands
```

원본 580-LoC subprocess CLI 는 `~/core/archive_sim-universe/cli/sim-universe.hexa` 묘비에 freeze.

## 5. 거버넌스 변경 (AGENTS.tape)

### 5.1 `@L l1` 추가
```
stdlib/sim_universe/ -> "★ Sim-Universe — virtual-universe runtime (26 modules · ~32k LoC · τ-clock + multiverse + qpu_bridge + 16 experiments). RFC 046 scaffold absorbed of ~/core/sim-universe. see §0 sim_universe_stack."
```

### 5.2 §0 `@N sim_universe_stack`

substrate / experiments / cli / honest_scope / qrng_dependency / archive / governance / DOI / RFC chain / status 필드. 전체 텍스트 본 RFC 의 변경된 `AGENTS.tape` 참고.

### 5.3 신규 `@D` (2개)
- `g_sim_universe_honest_scope` — 각 experiment 가 "honest scope" 선언 의무
- `g_sim_universe_qrng_consumer` — ouroboros_qrng → stdlib/qrng provider 의존

### 5.4 신규 `@F` (1개)
- `f_sim_universe_lattice_qcd_claim` — overreach 금지 (lattice QCD / Einstein equation / SM physics 라고 주장 X)

### 5.5 신규 `@X` (1개)
- `x_archive_sim_universe` — 묘비 pointer + Zenodo DOI 10.5281/zenodo.20102970

## 6. 호환성

- 원본 `dancinlab/sim-universe` 패키지 → private (사용자 액션)
- 외부 consumer 없음 (sim-universe 는 자체 응용; hexa-lang 외 consumer 미확인)
- `stdlib/qrng/` (RFC 044) 와 cross-reference: Phase B 에서 `ouroboros_qrng` 이 `use "stdlib/qrng/*"` 로 호출 — 양방향 의존 없음 (one-way: sim_universe → qrng)

## 7. Falsifier (Phase A 인수 조건)

1. **F-RFC046-A-PARSE**: `hexa parse stdlib/sim_universe/sim_universe.hexa` 종료코드 0.
2. **F-RFC046-A-CLI**: `hexa run stdlib/sim_universe/sim_universe.hexa` 가 module inventory + tier table + caveats 출력 (status default).
3. **F-RFC046-A-HELP**: `hexa run stdlib/sim_universe/sim_universe.hexa --help` 가 SUBSTRATE/EXPERIMENTS 섹션 + 22 subcommand 표 출력.
4. **F-RFC046-A-DISPATCH**: `hexa parse self/main.hexa` 종료코드 0. `else if sub == "sim-universe"` 분기 + cmd_help STDLIB CLI 섹션 추가 확인.
5. **F-RFC046-A-TAPE**: AGENTS.tape grep — `@N sim_universe_stack`, `@D g_sim_universe_honest_scope`, `@D g_sim_universe_qrng_consumer`, `@F f_sim_universe_lattice_qcd_claim`, `@X x_archive_sim_universe`, `@L l1 stdlib/sim_universe/` 모두 존재.
6. **F-RFC046-A-ARCHIVE**: `~/core/archive_sim-universe/AGENTS.tape` byte-identical to `~/core/sim-universe/AGENTS.tape`. `ABSORBED.md` 존재. `chmod -R a-w` 적용.
7. **F-RFC046-A-RFC-DOC**: 본 RFC 문서 `proposals/rfc_046_sim_universe_absorption.md` 존재.

Phase B/C 의 코드-마이그레이션 falsifier 는 별도 RFC 046-A / RFC 046-B 에서 정의.

## 8. Risks

- **R1** — sim-universe README 의 honest-scope 캐베어가 stdlib README 흡수 후 손실. **Mitigation**: archive_sim-universe/README.md 전체 보존 (601-line 원본). stdlib README 에서 cross-link.
- **R2** — Phase B/C 가 영원히 deferred 상태로 머무름. **Mitigation**: 본 RFC 가 substrate vs experiments 분할 명확 + 후속 RFC 번호 (046-A, 046-B) 사전 할당.
- **R3** — `sim_universe.hexa` dispatcher 의 22 subcommand 매칭이 길어서 추가 시 누락 위험. **Mitigation**: README + dispatcher subcommand 목록 일치 (grep diff 가능).
- **R4** — qmirror upgrade (RFC 045 대기) 가 sim-universe 의존성에 영향. **Mitigation**: sim-universe 는 qmirror 의존 없음 (qrng 만 의존); RFC 045 land 영향 없음.

## 9. 후속

- **RFC 045** — qmirror absorption (qmirror upgrade in flight; re-fetch when ready)
- **RFC 046-A** — substrate code migration (anu_time / multiverse / qpu_bridge / sim_agent / ouroboros_qrng / godel_q / sr_harness / atlas_anu_corr / anu_stream / bostrom_test)
- **RFC 046-B** — 16 experiments code migration + per-experiment selftest sentinels + stdlib/test/test_sim_universe_*.hexa

---

**Co-author**: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
