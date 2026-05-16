# RFC-044 — `qrng` 흡수 (`stdlib/qrng/`)

- **상태**: **Active — landing in progress** (2026-05-16)
- **작성일**: 2026-05-16
- **선행**: 헌법 v2 (5 룰) — memory `project_hexa_lang_absorption_criterion`
- **흡수 시리즈 #1/3**: RFC 044 (qrng) → RFC 045 (qmirror) → RFC 046 (sim-universe)
- **사용자 결정 (2026-05-16)**: 세 repo 모두 nexus 식 archive 전환 — GitHub repo private + 로컬 `~/core/archive_<repo>/` 묘비
- **영향 영역**: `stdlib/qrng/` (신규) · `tool/hexa_qrng/` (신규) · `stdlib/test/test_qrng_*.hexa` (신규/확장) · `stdlib/qrng_anu.hexa` (silent delete) · `stdlib/qrng_anu.ai.md` (silent delete) · `AGENTS.tape` (`@L l1` + `@D` + `@F` + `@X` + `@N`) · `docs/qrng_anu_upstream_landing.md` (import update) · `docs/phase_delta_language_v2_spec.ai.md` (import update)

---

## 1. 동기 (Why)

`~/core/qrng/` v1.0.0 — 4,383 LoC `.hexa`, 9 backends T0..T3 + NIST SP 800-22 tier-1+ audit + CLI — 는 hexa-lang 의 stdlib 와 두 곳에서 동일한 SSOT 를 유지하는 상태였다 (registry `hx install qrng` + partial `stdlib/qrng_anu.hexa` 191 LoC). 헌법 v2 (2026-05-13) 가 정착하면서 모든 dancinlab consumer (nexus, qrng, qmirror, sim-universe) 의 알고리즘+δ 패턴은 hexa-lang stdlib 으로 흡수되는 방향이 결정됐다.

qrng 는 흡수 후보 중 가장 깨끗:
- pure-hexa, raw9 strict 컴플라이언트 (no `.py`)
- zero stdlib import 의존성
- 5 IMPLEMENTED 백엔드 + 4 T2 STUB_CREDENTIALED + 1 audit module + 13 module + 12 test + CLI 가 모두 selftest 통과
- 헌법 v2 룰 4 (외부 자원 try-CLI-or-fallback) 의 reference impl 로 적합

GitHub repo `dancinlab/qrng` 는 private 전환되며, 로컬 `~/core/qrng/` SSOT 는 `~/core/archive_qrng/` 로 freeze. 라이브 코드는 본 RFC 가 `stdlib/qrng/` 로 이전한다.

## 2. 헌법 v2 룰 매핑

| 룰 | 본 RFC 에서의 처리 |
|---|---|
| 1 (rodata 시드) | 비해당 — qrng 는 알고리즘 + 외부 자원이지 atlas 시드 콘텐츠가 아니다 |
| 2 (알고리즘 흡수) | NIST SP 800-22 5 tests (audit.hexa) + 9-backend registry + router fallback chain + LCG mock + ANU REST parser + CURBy Bell-test parser + NIST Beacon ECDSA parser → `stdlib/qrng/` |
| 3 (메타 frozen) | AGENTS.tape · CHANGELOG · README · CITATION.cff · LICENSE · RELEASE_NOTES · TAPE-AUDIT · hexa.toml · install.hexa · docs/ · examples/ → `~/core/archive_qrng/` 묘비. 재해석 없이 그대로 |
| 4 (외부 자원 δ) | 9 backends 모두 try-CLI/network-or-fallback. `QRNG_LIVE=1` / vendor secret 있으면 실호출, 없으면 결정적 mock_qrng 또는 fixture JSON. 본 RFC 의 reference impl |
| 5 (overlay) | 비해당 — qrng 는 발견 누적 도구가 아닌 entropy 제공자. drill round 결과 누적 같은 overlay 사용처 없음 |

## 3. 아키텍처 전환 — 표준 프로그램 → 라이브러리

qrng repo 의 모듈 디자인은 hexa-lang stdlib idiom 과 구조적으로 다르다:

| 특성 | qrng repo (현재) | hexa-lang stdlib (목표) |
|---|---|---|
| 진입점 | 각 모듈에 `fn main()` + `__QRNG_*__ PASS` sentinel print | 라이브러리 모듈 (no main); 별도 `test_*.hexa` 가 진입점 |
| 구조체 정의 | 9개 backend 가 동일한 `QrngBytes`/`QrngSourceMeta` 등 5개 정의 복사-붙여넣기 | `source.hexa` 단일 SSOT; 다른 모듈은 `use "stdlib/qrng/source"` |
| Inter-module dispatch | registry/router → subprocess `hexa run <backend>.hexa` → stdout sentinel parse | 직접 함수 호출 (`use` import 후 `qrng_source_collect_anu(n, seed)`) |
| Selftest | `main()` 안에 `_selftest()` 호출 → sentinel print | `stdlib/test/test_qrng_<backend>.hexa` 분리 파일 |

흡수 시 각 backend `.hexa` 는:
1. 중복된 5개 정의 (struct + 3 helper fn) 제거
2. `use "stdlib/qrng/source"` 추가
3. `fn main()` + `_selftest()` 를 `stdlib/test/test_qrng_<backend>.hexa` 로 분리
4. Public functions (`qrng_source_meta_<backend>()`, `qrng_source_collect_<backend>(n, seed)`) 만 유지

registry/router 는:
- subprocess-dispatch (`if name == "anu" { return qrng_bytes_fail("anu: live deferred to wrapper") }`) → 직접 호출 (`if name == "anu" { return qrng_source_collect_anu(n, seed) }`)
- 모든 backend 모듈 `use` 로 import

총 변경: ~450 LoC duplicate struct 제거 + ~9 use 추가 + ~10 dispatch 함수 본문 교체. 신규 코드 없음.

## 4. 흡수 범위

### 4.1 File mapping

```
~/core/qrng/                              → /Users/ghost/core/hexa-lang/
  source/module/source.hexa  (84)         → stdlib/qrng/source.hexa
  mock_qrng/module/mock_qrng.hexa (92)    → stdlib/qrng/backends/mock_qrng.hexa
  anu/module/anu.hexa (138)               → stdlib/qrng/backends/anu.hexa  *
  curby/module/curby.hexa (305)           → stdlib/qrng/backends/curby.hexa
  nist_beacon/.../nist_beacon.hexa (309)  → stdlib/qrng/backends/nist_beacon.hexa
  ibm_quantum/.../ibm_quantum.hexa (209)  → stdlib/qrng/backends/cloud/ibm_quantum.hexa
  ionq/module/ionq.hexa (193)             → stdlib/qrng/backends/cloud/ionq.hexa
  rigetti/module/rigetti.hexa (204)       → stdlib/qrng/backends/cloud/rigetti.hexa
  braket/module/braket.hexa (217)         → stdlib/qrng/backends/cloud/braket.hexa
  hardware_qrng/.../hardware_qrng.hexa (199) → stdlib/qrng/backends/hardware_qrng.hexa
  audit/module/audit.hexa (838)           → stdlib/qrng/audit.hexa
  registry/module/registry.hexa (196)     → stdlib/qrng/registry.hexa
  router/module/router.hexa (171)         → stdlib/qrng/router.hexa
  qrng_main/module/qrng_main.hexa (167)   → stdlib/qrng/qrng_main.hexa
  cli/qrng.hexa (580)                     → DEFERRED to RFC 044-B (see §11)
  tests/test_*.hexa (12 files, ~251)      → stdlib/test/test_qrng_*.hexa (×9 consolidated)
  curby/module/fixtures/*.json            → stdlib/qrng/fixtures/curby_*.json
  nist_beacon/module/fixtures/*.json      → stdlib/qrng/fixtures/nist_beacon_*.json

  (frozen archive)
  AGENTS.tape · CHANGELOG.md · README.md · CITATION.cff · LICENSE ·
  RELEASE_NOTES_v1.0.0.md · TAPE-AUDIT.md · hexa.toml · install.hexa ·
  docs/ · examples/ · .gitignore   →   ~/core/archive_qrng/
```

`*` = `anu.hexa` 는 기존 `stdlib/qrng_anu.hexa` (191 LoC, 5 functions `qrng_anu_*`) 와 consolidate. 결과는 양 API 모두 유지: 새 registry API (`qrng_source_meta_anu`, `qrng_source_collect_anu`) + 기존 익숙한 wrapper (`qrng_anu_uint8`, `qrng_anu_uint8_live`, `qrng_anu_chunked`, `qrng_anu_parse_response`, `qrng_anu_live_enabled`). 후자는 새 API 위 thin wrapper. anima sister-repo 가 후자를 직접 부르고 있어 호환성 유지.

### 4.2 Public API surface (`use "stdlib/qrng"` 진입)

```hexa
// 데이터 타입 (stdlib/qrng/source.hexa)
struct QrngBytes      { ok, n_bytes, bytes_, sha256_hex, nist_pass, message }
struct QrngSourceMeta { name, tier, throughput_bps, cost_usd, lead_days,
                        is_quantum, is_local, is_free, status, vendor }
struct AuditTestResult { name, p_value, passed, skipped, note }
struct AuditedQrngBytes { ok, n_bytes, bytes_hex, audit_pass, tests_run,
                          audit_level_requested, audit_level_delivered,
                          tier, vendor, alpha, message }

// 직접 backend 호출 (stdlib/qrng/backends/<name>.hexa)
fn qrng_source_meta_anu() -> QrngSourceMeta
fn qrng_source_collect_anu(n_bytes: int, seed: int) -> QrngBytes
// ... 같은 패턴 9 backends

// Registry/router (stdlib/qrng/registry.hexa + router.hexa)
fn qrng_registry_names() -> [str]
fn qrng_registry_meta(name: str) -> QrngSourceMeta
fn qrng_registry_collect(name: str, n_bytes: int, seed: int) -> QrngBytes
fn qrng_route_collect(n_bytes: int, seed: int) -> RouterResult
struct RouterResult { final_backend, attempts: [str], bytes: QrngBytes }

// 통합 entry — audit + collect 단일 호출 (stdlib/qrng/qrng_main.hexa)
fn qrng_audited_bytes(n_bytes: int, audit_level: str, vendor: str) -> AuditedQrngBytes
fn qrng_main_aggregate() -> AggregateResult   // 12-sentinel selftest

// 익숙한 wrapper (stdlib/qrng_anu.hexa 흡수, anima 호환)
fn qrng_anu_uint8(length: int) -> [int]
fn qrng_anu_uint8_live(length: int) -> [int]
fn qrng_anu_chunked(total: int, sleep_ms: int) -> [int]
fn qrng_anu_parse_response(text: string) -> map
fn qrng_anu_live_enabled() -> bool
```

### 4.3 NIST SP 800-22 audit (5 tests)

`stdlib/qrng/audit.hexa` (838 LoC) — α=0.01 기본:
- §2.1 Monobit (frequency)
- §2.2 Frequency within a Block (M=128)
- §2.3 Runs (monobit precondition)
- §2.4 Longest Run of Ones (M=128, K=5, N=49)
- §2.6 Discrete Fourier Transform spectral (n ≤ 1024, O(n²) cap)

원본은 `@cite` annotation 없이 inline 주석으로 NIST SP 800-22 Rev. 1a 참조. **본 RFC 도 같은 패턴 유지** — atlas binding 없음. 이유:
1. `compiler/atlas/embedded.gen.hexa` 가 frozen (`atlas.n6` 소스 nexus 2df92aed 에서 retired); 현재 atlas 신규 entry 추가 경로 미정.
2. 기존 stdlib (qrng_anu, http, json, ...) 어디서도 `@cite` 사용 안 함 — stdlib 는 atlas binding 면제.
3. g6 citation-enforced-strict-lint 는 `@cite` annotation 있는 라인만 검증 — 없으면 stage 4 통과.

NIST 참조는 audit.hexa docstring + 각 test 함수 head 주석에 명시 (URL 포함).

## 5. 거버넌스 변경 (`AGENTS.tape`)

### 5.1 `@L l1` 추가
```
stdlib/qrng/ -> "Quantum RNG — 9 backends T0..T3 + NIST SP 800-22 audit. RFC 044 absorption of ~/core/qrng (헌법 v2 룰 4 reference impl)."
tool/hexa_qrng/ -> "qrng CLI — status · collect · selftest · chain · meta. RFC 044."
```

### 5.2 §0 `@N qrng_stack` 추가 (`nn_stack` 옆)
```
@N qrng_stack := "stdlib/qrng — 9-backend QRNG provider + NIST audit" :: note [d=2026-05-16 active]
  provider = "stdlib/qrng/backends/{mock_qrng, anu, curby, nist_beacon, hardware_qrng} (5 IMPLEMENTED) + cloud/{ibm_quantum, ionq, rigetti, braket} (4 T2 STUB_CREDENTIALED)"
  algorithm = "stdlib/qrng/audit.hexa — NIST SP 800-22 tier-1+ (5 tests, α=0.01)"
  routing = "stdlib/qrng/registry.hexa + router.hexa — env-driven fallback chain (QRNG_SOURCE · QRNG_FALLBACK_CHAIN · QRNG_LIVE · QRNG_HW_LIVE)"
  entry = "qrng_audited_bytes(n, level, vendor) — entropy + audit 단일 호출"
  cli = "tool/hexa_qrng/qrng.hexa — 5 subcommands"
  governance = "see @D g_qrng_audit_required, g_qrng_honest_vendor, g_qrng_provider_only"
  archive = "~/core/archive_qrng/ — frozen 묘비 (헌법 v2 룰 3)"
  status = "ABSORBED 2026-05-16 from dancinlab/qrng v1.0.0 (Zenodo DOI 10.5281/zenodo.20102966)"
```

### 5.3 신규 `@D` (3개)
```
@D g_qrng_audit_required := "qrng audit on T1/T3 paths" :: governance [required d=2026-05-16]
  rule = "Any code path returning live quantum entropy (tier ≥ T1) MUST be exercisable through qrng_audited_bytes() with NIST SP 800-22 tier-1+ audit."
  apply = "Skipping audit on T1/T3 backends is a release blocker."
  authority = "NIST SP 800-22 Rev. 1a"
  source = "qrng AGENTS.tape g1 (migrated 2026-05-16)"

@D g_qrng_honest_vendor := "qrng vendor classification honesty" :: governance [required d=2026-05-16]
  rule = "QrngSourceMeta.is_quantum follows vendor self-classification; honest-caveat ships in module docstring + meta.message."
  examples = "nist_beacon.is_quantum=0 (mixed entropy); hardware_qrng.is_quantum=1 (IDQ/ESP32 vendor assertion, independent NIST validation NOT performed)."
  source = "qrng AGENTS.tape g2 (migrated 2026-05-16)"

@D g_qrng_provider_only := "qrng = provider-side only" :: governance [required deny:write d=2026-05-16]
  rule = "stdlib/qrng/ returns raw bytes + provenance. No HMAC-DRBG / NIST SP 800-90A construction belongs here."
  why = "Amplification is consumer concern (qmirror amplifier · hexa-bio). Provider/consumer boundary deliberate."
  source = "qrng AGENTS.tape g3 (migrated 2026-05-16)"
```

### 5.4 신규 `@F` (1개)
```
@F f_qrng_silent_mock_downgrade := "silent mock downgrade" :: governance [required deny:write d=2026-05-16]
  pattern = "Router falls back to mock_qrng (T0) without preserving tier/vendor/message in audit_level_delivered or RouterResult.attempts."
  remedy = "router MUST set audit_level_delivered to 'tier1-none' or 'none' and record attempts list."
  source = "qrng AGENTS.tape f_weak_entropy (migrated 2026-05-16)"
```

### 5.5 신규 `@X` (1개)
```
@X x_archive_qrng := "qrng 묘비 archive" :: archive [d=2026-05-16 active]
  url = "file://~/core/archive_qrng/"
  scope = "Frozen historical SSOT of dancinlab/qrng v1.0.0 — AGENTS.tape, CHANGELOG, README, CITATION.cff, RELEASE_NOTES, hexa.toml, install.hexa, docs/, examples/. 재해석 없음 (헌법 v2 룰 3)."
  github = "dancinlab/qrng (private 2026-05-16 후)"
  doi = "10.5281/zenodo.20102966"
```

## 6. 호환성

### 6.1 `stdlib/qrng_anu.hexa` 흡수

기존 191 LoC + 5 public functions (`qrng_anu_uint8` 등) → `stdlib/qrng/backends/anu.hexa` 안의 wrapper 로 보존. 함수명 + 시그너처 변경 없음. `stdlib/qrng_anu.hexa` 원본 파일은 silent delete (per `[[feedback_raw_own_no_mention]]`). 호환 shim 없음, `// moved to ...` 주석 없음.

### 6.2 Consumer 업데이트

3개 파일이 old import path 사용:
1. `docs/qrng_anu_upstream_landing.md` — `use "stdlib/qrng_anu"` → `use "stdlib/qrng"`
2. `docs/phase_delta_language_v2_spec.ai.md` — 동일 변경 (lines 89, 101-110)
3. `stdlib/test/test_qrng_anu.hexa` (146 LoC) — import 갱신 + qrng/tests/test_anu.hexa 와 머지

Sister repo `~/core/anima/` 는 함수명 직접 호출 (`qrng_anu_uint8_live`) — 본 RFC 의 wrapper 가 함수명 유지하므로 변경 불필요. 향후 anima 가 새 API 쓰고 싶으면 anima 측 RFC.

### 6.3 추가/삭제 요약

```
+ stdlib/qrng/                         (신규 디렉토리, 14 files, ~3,930 LoC)
+ stdlib/qrng/backends/cloud/          (신규 sub-디렉토리, 4 T2 stubs)
+ stdlib/qrng/fixtures/                (신규 sub-디렉토리, 2 JSON)
+ tool/hexa_qrng/                      (신규 디렉토리, 1 file, 580 LoC)
+ stdlib/test/test_qrng_source.hexa
+ stdlib/test/test_qrng_curby.hexa
+ stdlib/test/test_qrng_nist_beacon.hexa
+ stdlib/test/test_qrng_mock.hexa
+ stdlib/test/test_qrng_hardware.hexa
+ stdlib/test/test_qrng_registry.hexa
+ stdlib/test/test_qrng_router.hexa
+ stdlib/test/test_qrng_audit.hexa
+ stdlib/test/test_qrng_cloud_stubs.hexa
~ stdlib/test/test_qrng_anu.hexa       (확장: 기존 146 LoC + qrng/tests/test_anu.hexa 머지)
~ AGENTS.tape                          (@L l1 · @N qrng_stack · @D g_qrng_* ×3 · @F f_qrng_* · @X x_archive_qrng)
~ docs/qrng_anu_upstream_landing.md    (use 경로 갱신)
~ docs/phase_delta_language_v2_spec.ai.md (use 경로 갱신)
- stdlib/qrng_anu.hexa                 (silent delete; content → stdlib/qrng/backends/anu.hexa)
- stdlib/qrng_anu.ai.md                (silent delete)
```

## 7. 구현 단계 + 게이트

| Phase | 작업 | 게이트 |
|---|---|---|
| 0 | 사전 점검 — 워크트리 생성 (`/tmp/hexa-lang-rfc044` off origin/main), baseline `hexa parse stdlib/qrng_anu.hexa` | OK ✅ (완료) |
| 1 | 본 RFC 문서 작성 (atlas 통합 skip) | RFC 파일 존재 |
| 2 | File migration + library-ification (14 modules + CLI + 9 tests) | 각 파일 `hexa parse` PASS |
| 3 | AGENTS.tape mutation (@L, @N, @D ×3, @F, @X) | tape diff review |
| 4 | Build + test gate — `hexa build stdlib/qrng/qrng.hexa` · `hexa build tool/hexa_qrng/qrng.hexa` · 9 stdlib/test 실행 · 12-sentinel selftest · NIST audit (~3-4 min) | 모든 sentinel PASS |
| 5 | Archive freeze `~/core/archive_qrng/` (read-only) | ABSORBED.md 존재 + chmod a-w |
| 6 | Single bundled commit (`feat(stdlib): RFC 044 — absorb qrng v1.0.0 into stdlib/qrng/`) | git log 확인 |
| 7 | (out-of-band, user) GitHub repo private 전환 + deprecation README + `~/core/qrng/` 로컬 정리 (선택) | — |

## 8. Falsifier (검증 비협상)

1. **F-RFC044-LIB**: `hexa build stdlib/qrng/qrng.hexa -o /tmp/qrng_entry` 종료코드 0, 바이너리 생성.
2. **F-RFC044-CLI** ⊘ DEFERRED to RFC 044-B (CLI subprocess architecture doesn't translate to library; see §11).
3. **F-RFC044-SENT**: `hexa run stdlib/test/test_qrng_*.hexa` × 9 모두 sentinel `__QRNG_*__ PASS` 출력. `test_qrng_anu.hexa` 가 합쳐진 20+ cases 에서 20+/20+ PASS (회귀 없음).
4. **F-RFC044-AUDIT**: `qrng_audited_bytes(1024, "tier1+", "mock_qrng")` 가 `audit_pass=1` + `tests_run.len()=5` + `audit_level_delivered="tier1+"` 반환. (live ANU 는 `QRNG_LIVE=1` opt-in, CI 비차단.)
5. **F-RFC044-DET**: `qrng_source_collect_mock_qrng(8, 42)` 두 번 호출 시 `bytes_` 바이트 동일 (deterministic LCG).
6. **F-RFC044-TIER**: `qrng_registry_meta("nist_beacon").is_quantum == 0` (mixed entropy honesty) **AND** `qrng_registry_meta("curby").is_quantum == 1` (Bell-test 양자) **AND** `qrng_registry_meta("hardware_qrng").is_quantum == 1` (vendor assertion).
7. **F-RFC044-STUB**: `qrng_registry_collect("ibm_quantum", 4, 1).ok == 0` (T2 stub fail-closed without secret).
8. **F-RFC044-ARCH**: `~/core/archive_qrng/AGENTS.tape` 존재 + 내용이 `~/core/qrng/AGENTS.tape` 와 byte-identical (freeze 무손실). `ABSORBED.md` 존재. 디렉토리 read-only (chmod a-w 적용).
9. **F-RFC044-NOLEAK**: `find /tmp/hexa-lang-rfc044/stdlib/qrng_anu.hexa /tmp/hexa-lang-rfc044/stdlib/qrng_anu.ai.md` 두 파일 모두 부재 (silent delete 확인).
10. **F-RFC044-TAPE**: `AGENTS.tape` 에서 `@L l1` 가 `stdlib/qrng/` 행을 포함, `@D g_qrng_audit_required`/`g_qrng_honest_vendor`/`g_qrng_provider_only` 와 `@F f_qrng_silent_mock_downgrade`, `@X x_archive_qrng` 모두 grep 가능.

전 10개 falsifier PASS 가 RFC 044 인수 조건. 1개라도 FAIL 시 Phase 단위 rollback (`git restore` + `rm -rf ~/core/archive_qrng/`).

## 9. Risks

- **R1** — qrng 의 process-based architecture 를 library-ify 하는 과정에서 함수 호출 그래프 오류. Mitigation: Phase 2 per-file `hexa parse` 게이트 + Phase 4 통합 `hexa build` 게이트.
- **R2** — `qrng_anu_*` 5 함수 wrapper 가 anima 호환 깨지면 anima 빌드도 깨짐. Mitigation: wrapper 가 함수명/시그너처 정확히 보존 (변경 없음). 시그너처 변경 시 R2 발생, 그 때만 anima 측 RFC 발사.
- **R3** — `test_qrng_audit.hexa` wall time 3-4 분 (DFT O(n²)). CI 시간 증가. Mitigation: 본 RFC 의 commit message 에 baseline 변동 명시.
- **R4** — 워크트리 `/tmp/hexa-lang-rfc044` 가 `/tmp` 정리 시 사라짐. Mitigation: Phase 6 커밋 후 즉시 `git push origin rfc044-qrng-absorption` 권장 (선택).

## 10. 후속

- RFC 045 — `qmirror` 흡수 (47k LoC, 25+ modules) — `stdlib/quantum/` + `stdlib/quantum/experiments/`
- RFC 046 — `sim-universe` 흡수 (32k LoC, 26+ modules) — `stdlib/sim_universe/` + `stdlib/sim_universe/experiments/`
- atlas SSOT 복원: nexus 2df92aed 에서 retired 된 atlas.n6 가 복원되면 본 RFC 의 NIST SP 800-22 5 tests 를 별도 atlas-add RFC 로 `@P` 등록 가능.

## 11. 본 RFC 에서 deferred — CLI (RFC 044-B)

`~/core/qrng/cli/qrng.hexa` (580 LoC) 는 `_run_module` subprocess + sentinel-parse 아키텍처로 설계됨. stdlib 의 library 아키텍처와 충돌 (back end 모듈은 main() 없음). 본 RFC 는 CLI 를 흡수하지 않고 `~/core/archive_qrng/cli/qrng.hexa` 묘비에 freeze.

후속 **RFC 044-B** 에서 thin CLI (~150 LoC) 작성:
- `use "stdlib/qrng/registry"` / `router` / `audit` 등 library 직접 호출
- 5 subcommands 유지 (status · collect · selftest · chain · meta)
- subprocess + sentinel parse 제거
- `tool/hexa_qrng/qrng.hexa` 신규

F-RFC044-CLI falsifier 는 044-B 로 이전. 044 본체에서는 library + audit + tests 만 검증.

---

**Co-author**: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
