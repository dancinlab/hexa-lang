# stdlib/PLAN.md — hexa-matter / hexa-bio → hexa-native 이관 마스터 플랜

> ## 🎯 GOAL (2026-05-18, 사용자 확정)
> **`hexa-matter` · `hexa-bio` 두 프로젝트가 hexa stdlib & hexa cli 만으로
> 돌아가게 한다 — Python 종속 0, 기능 후퇴 0, 측정으로 증명하면서.**
>
> 2-stage (모든 작업이 이 단계에 trace):
> - **Stage 1 — 현 구현 이관**: 두 프로젝트의 `.py` 구현을 hexa-native
>   `.hexa` 로. 외부 의존 0(stdlib-only) 모듈은 즉시 무손실 이관.
> - **Stage 2 — 종속 라이브러리 hexa-native 포팅**: numpy·torch·ase·
>   pymatgen·rdkit·NNP·qiskit·pyscf 를 hexa stdlib 패키지로 재구현
>   (no python/c shell-out, `.roadmap.stdlib` RC1).
>
> 불변 규율 (g3, lattice-as-tool): **가짜 진전 0**. SKIP-mode 포팅으로
> 동작하던 기능을 후퇴시키는 것은 "이관"이 아니라 over-claim — 금지.
> 측정된 거리만 기록, 달성 주장 아님 (ANIMA GOAL.md 와 동형).
>
> 전수조사·매핑 SSOT = 본 디렉토리 `README.md` §science-stack.
> 이 파일 = 이관 운영 로드맵 (editable head + append-only `## 진행 로그`).

---

## 0. 현재 상태 (2026-05-18)

전수조사: `hexa-matter` (.py 2362) + `hexa-bio` (.py 6192) 모든 import
추출 완료. 외부 종속 → hexa stdlib 8패키지 매핑 확정 (README §science-stack).

science-stack 패키지: `nd`·`grad`·`net` = 기존 자산 remap,
`atoms`·`crystal`·`mol`·`mlff`·`quantum` 5개 = SCAFFOLD (mod.hexa, Stage 2 대기).

## 1. 측정된 거리 (g3 — over-claim 금지)

전체 ≈ **8554 .py**. "100% closure" 는 한 세션 도달 대상이 아닌 north-star.

| 단위 | 규모 | 1세션? | 상태 |
|---|---|---|---|
| hexa-matter stdlib-only 6모듈 | 완료 | — | ✅ **완전 이관** (`.py` 제거, selftest 38/38) |
| selftest 26 게이트 (.py, stdlib-only) | 26 × 100~400줄 + run_all.sh union 재배선 (all-or-nothing) | △ 1세션 한계 | ⏳ 무손실 가능 — 다음 단위 |
| hexa-matter science-stack 7모듈 (ase/pymatgen/rdkit/mp_api/NNP) | Stage 2 선행 필수 (SKIP-mode = 기능 후퇴 = 부정직) | ✗ | 🔒 Stage 2 차단 |
| hexa-matter `_absorption_bridge` 16어댑터 | Stage 2 선행 | ✗ | 🔒 Stage 2 차단 |
| hexa-bio .py 6192 (qiskit 289 · pyscf 47 · numpy · rdkit) | 거대 | ✗ | ⏳ stdlib-only 부분만 Stage-1 가능 |
| Stage 2 (pymatgen·qiskit·torch hexa-native 재구현) | 메가 — 수개월+ | ✗✗ | 🔬 별도 장기 트랙 |

진척률: 8554 중 **6 완전 이관(T1)** + **26 무손실 이관·패리티 검증
완료(T2)** + 나머지(T3 hexa-bio · T4/T5 science-stack Stage 2) 차단.

## 2. 확립된 무손실 이관 패턴 (이후 전 트랙 적용)

1. Python `dict` → parallel hexa arrays (`[str]` keys + `[float]`/`[str]`)
2. `argparse --selftest` → `main()` inline case 검증 + `__HEXA_MATTER_*__` sentinel
3. `raise ValueError` → sentinel 반환값 + caller 검사
4. Python `re` → **무손실 3택**(T2 에서 확립, Stage-1 근사 안 씀):
   (a) 순수 prefix/substring 은 hexa `split`/`contains` 직접;
   (b) digit-shape·char-class·word-boundary 정규식은 `grep -E` 의
   ERE 가 Python `re` 의 문자그대로 등가(`\d`→`[0-9]` `\s`→`[[:space:]]`
   `(?:..)`→`(..)` `\b` 유지) — hexa 는 오케스트레이션만;
   (c) Python `\s` 가 window join 의 `\n` 을 가로지르는 케이스
   (hardwall·vendor)는 precompute-miss 만 ±window join 후 정밀 재-grep
   → 코퍼스 바이트-패리티. `F-tag`/`CAND_RE` 등은 정확 char-class 스캐너
   hand-roll. **g3: 검증력 후퇴(substring 근사) 금지를 전수 준수.**
5. file I/O·정규식 위임 → `exec()` (hexa-native shell builtin; grep/sed/
   awk/coreutils = stdlib-equivalent shell, python shell-out 아님)
6. **aggregator union 순회**: `.hexa` 있으면 `hexa run`, 없으면 `.py`/`.sh`
   fallback — 모듈별 점진 이관에 공존 안전(all-or-nothing 아님)
   (`pyproject_smoke.sh` + `run_all.sh` 적용 완료)

## 3. 단계별 로드맵

- **T1** ✅ hexa-matter stdlib-only 6모듈 (`_hexa_bridge/module/*.hexa`)
- **T2** ✅ selftest **26/26** 게이트 → `_hexa_bridge/selftest/*.hexa`,
  `run_all.sh` union 재배선 완료(hexa-first, `.py`/`.sh` fallback —
  all-or-nothing 아님, 모듈별 점진·안전). 전 게이트 `.py` 출력
  **바이트-패리티 검증** 후 채택(무손실): grep -E ERE ≡ Python `re`,
  char-class 스캐너 hand-roll, cross-line `\s` 케이스(hardwall·vendor)는
  ±window join 정밀 재확인으로 803/798/5·30/30/0 정확 일치.
  `.py` 원본은 fallback·재패리티용으로 **유지**(제거는 별도 결정).
- **T3** ⏳ hexa-bio stdlib-only 이관 — **전수조사 완료 2026-05-18**:
  119 `.py` 중 **104 stdlib-only(지금 이관)** + 15 Stage-2(`_qiskit_
  bridge/module/` 전량, T4/T5). 분류:
  - `_python_bridge/module/*.py` **55/55** stdlib-only (생물물리
    시뮬레이터; json/math/re/argparse 만)
  - `_absorption_bridge/` 어댑터 9 + `selftest/` 래퍼 10 = **19**
    stdlib-only (offline `--selftest` 경로; science import 는 live-path
    guarded)
  - `selftest/*.py` **30/30** stdlib-only (`atlas_atom_proofs.py` 는
    sympy guarded→proof-5 SKIP 유지)
  - `selftest/*.sh` 16 bash 래퍼(.py 아님; aggregator)
  스코어보드: `selftest/run_all.sh` **35/35 PASS**(거버넌스 선언,
  AGENTS.tape) — 동적 `$passes/$fails` STRICT-with-SKIP. **verify/ 층
  없음**(hexa-matter 와 달리 구조-폐쇄 tier 부재 — 이관 시 신설 검토;
  `selftest/module/selftest.hexa` stub 기존). `_hexa_bridge/` 미존재.
  리스크: docstring/배너 non-ASCII(`—─✓✗αβ⇌`)는 로직/sentinel 밖 —
  배너 transliterate(byte-index 안전); guarded-import SKIP-not-FAIL
  계약·subprocess-out SKIP 보존; 대형 파일(800+L)은 양(量)이슈.
  하위 트랙: **T3a** `_python_bridge/module` 55 · **T3b** `selftest`
  30 게이트 · **T3c** `_absorption_bridge` 19. run_all.sh union 선(先)
  재배선 → 게이트별 점진·바이트-패리티(T2 패턴 재사용).

  ⚠️ **정제 발견 (2026-05-18, 착수 직후 — g3 측정된 거리)**:
  "stdlib-only"(third-party 사이언스 pkg 無) ≠ "hexa 즉시 이관 가능".
  hexa-bio 게이트는 hexa-matter(텍스트/grep 기반)와 달리 **JSON·공유-
  라이브러리 의존이 지배적**: `json.load/dumps`(registry.jsonl·schema·
  witness), 공유 `json_schema_validator.validate`(draft-07 subset),
  `hashlib.sha256`(witness 해시), subprocess 시뮬레이터 오케스트레이션.
  hexa 에 native `json` 부재 → **hexa-lang `stdlib/json`(parse +
  sort_keys canonical dump)이 T3-json 게이트의 선결조건**(T4 stdlib
  빌드와 교집합). 따라서 T3 재-삼분:
  - **T3-text** (지금 이관 가능; exec/grep/stat 기반): `r1_symlink_
    audit` ✅ — 이런 부류만 무손선 즉시 이관.
  - **T3-json** (선결: `stdlib/json` + 공유-lib 포팅): C5 conformance·
    json_schema_validator·regression_audit(sha256+subprocess)·witness
    계열 — `stdlib/json` 착수 후 진행.
  - **T3-sim** (`_python_bridge/module` 55 생물물리 시뮬): 대부분 순수
    수치이나 일부 JSON I/O — text 부분 우선, JSON I/O 는 T3-json 의존.
  결론: T3 의 진짜 즉시-이관 부분집합은 raw "104" 보다 작다. 정직한
  경로 = `stdlib/json` 을 먼저 세우고(이는 T4 자산이기도) T3-json 해금.
  진행: `cc994c9`(hexa-bio) union+r1 바이트-패리티 — **T3 1/104 검증**.

  📍 **선결조건 정밀 지정 (다음 루프 시작점 — 재조사 불필요)**:
  hexa-lang 에 JSON **write-side 만** 존재 — `stdlib/alloc/json.hexa`
  (170L): `json_stringify_value` · `json_dump_pretty` ·
  `json_object_set` · `json_array_push`. **파서 부재**(`parse/loads/
  decode` 없음), sort_keys canonical dump 부재. `json.hexa` 는 alloc
  로의 shim, `jsonl_pool.hexa` 는 IPC 풀(파서 아님). ⇒ 다음 구체
  작업 = `stdlib/alloc/json.hexa` 에 **(1) `json_parse(s)->value`
  재귀하강 파서**(obj/arr/str/num/true/false/null·escape·UTF-8) +
  **(2) `json_dumps_canonical(v)`** = Python `json.dumps(x,
  sort_keys=True)` **바이트-정확**(separators `, `/`: `,
  ensure_ascii 기본, 키 재귀 정렬, int/float 표기 일치) 추가. 검증:
  hexa-bio `registry.jsonl`/schema/fixture 라운드트립 + sha256(via
  `shasum -a 256`)이 Python 과 일치. 이게 서면 T3-json 다수 +
  `regression_audit` 해시줄 + T4 자산 동시 해금. (rfc043-hexa-torch
  브랜치, hexa atlas PR-only 규약 유의 — 직접 fold-to-live 금지.)
- **T4** 🔒 Stage 2 — `atoms`/`crystal`/`mol`/`mlff`/`quantum` 실구현
  (각 `mod.hexa` planned API 채움) → science-stack 의존 모듈/어댑터 해금
- **T5** 🔒 Stage 2 잔여 — `nd`/`grad` 정밀화, `_absorption_bridge` 16,
  hexa-bio 양자화학 (qiskit/pyscf hexa-native — 메가)

각 트랙은 끝나야 다음으로(T2 는 T1 패턴 의존, T4 는 T1~T3 무손실 완료 후).

---

## 진행 로그 (append-only, 최신이 아래)

- 2026-05-18 `9db6d47e` (hexa-lang) — science-stack 8매핑 + 5 scaffold
  (atoms/crystal/mol/mlff/quantum mod.hexa) + README SSOT.
- 2026-05-18 `764c674` (hexa-matter) — T1 6 stdlib-only 모듈 → hexa-native
  `.hexa` (전부 PASS).
- 2026-05-18 `29f37ff` (hexa-matter) — T1 완료: 6 `.py` 제거,
  pyproject_smoke union 순회, selftest 38/38 유지.
- 2026-05-18 — 본 PLAN.md 기록 (이관 마스터 플랜 SSOT).
- 2026-05-18 `ae45c4b` (hexa-matter) — T2 20/26: nist_anchor · r1_symlink
  (sh→hexa) · lattice_fit · n6_axis · regression · cross_doc ·
  registry_consistency. lattice_fit 은 grep-pipeline(token|vendor\b|neg)
  으로 .py 더블-룩어헤드 정규식 바이트-패리티.
- 2026-05-18 `bf577fa` (hexa-matter) — T2 **26/26 완료**: c_handoff ·
  novel_verb_xref · cross_link_integrity · hardwall_provenance ·
  falsifier_wellformed · vendor_citation_completeness. 전 게이트 .py
  출력 바이트-패리티(803/798/5 · 214/17/0 · 30/30/0 …). selftest
  38/38, run_all.sh union 26/26 `[hexa]` 실행. `.py` 는 fallback·
  재패리티 레퍼런스로 유지(제거는 별도 결정). Stage-1 substring
  근사 미사용 — g3 검증력 후퇴 0건.
- 2026-05-18 `af1141a` (hexa-matter) — verify/closure_consistency README
  badge regex 복구(20a919d 가 남긴 verify 3/4 회귀 → **4/4**).
- 2026-05-18 `f0ecc06` (hexa-matter) — Phase HX 문서 반영
  (INIT.md·AGENTS.tape·AGENTS.md·LESSONS.md). hexa-matter T1/T2
  전부 커밋·작업트리 clean(raw#10 정리는 d1a560d 히스토리).
- 2026-05-18 — **T3 전수조사 완료** (hexa-bio): 119 .py 중 104
  stdlib-only(_python_bridge 55 · _absorption_bridge 19 · selftest 30)
  + 15 Stage-2(_qiskit_bridge 전량). 스코어보드 35/35, verify층 부재.
  매니페스트 §3 T3 에 기록. 다음: run_all.sh union 선재배선 → T3a/b/c
  게이트별 바이트-패리티 이관.
- 2026-05-18 `cc994c9` (hexa-bio) — T3 착수: `selftest/run_all.sh`
  hexa-first union 재배선(hexa-matter T2 패턴) + `r1_symlink_audit`
  .sh→.hexa **바이트-패리티**(stdout `checked=4 fail=0 warn=0` +
  exit 0/1/2 동일). `_hexa_bridge/{module,selftest}/` 신설. 무관한
  `case_studies/.../LANDSCAPE.md`(타인 변경) 미혼입.
- 2026-05-18 — **T3 정제 (g3 측정된 거리)**: 착수 직후 hexa-bio T3
  코퍼스가 JSON·공유-lib·sha256·subprocess 지배적임을 발견(§3 T3
  ⚠️ 블록). "stdlib-only 104" ≠ "즉시 이관 104". `regression_audit`
  (sha256-canonical-JSON + 4-subprocess) **연기**(union 으로 .py 유지
  → 무회귀). T3 재-삼분: T3-text(즉시·r1✅) / T3-json(선결
  `stdlib/json`) / T3-sim. 정직한 다음 수: hexa-lang **`stdlib/json`
  (parse + sort_keys canonical dump)** 신설 — T3-json 해금 + T4 자산.
  **측정된 거리: T3 1/104 검증 · 즉시-이관 부분집합은 104 미만.**
- 2026-05-18 — **선결조건 정밀화 (자산 점검)**: hexa 런타임에 이미
  `json_parse`/`json_stringify` 빌트인 존재(probe 검증). 이전 PLAN
  "파서 부재" 표기는 stdlib **파일** 한정 — 런타임은 동작. 따라서
  T3-json 의 read-side(파서)는 **이미 가용**, 추가 작업 0. 남은
  진짜 필요분은 `json_dumps_canonical`(Python `json.dumps(sort_keys=
  True)` 바이트-정확)뿐 → 이 자산만 신설하면 됨.
- 2026-05-18 `5b5b9809` (hexa-lang `rfc043-hexa-torch`) — **stdlib/
  alloc/json.hexa::json_dumps_canonical 착륙**. 재귀 키 정렬 +
  ensure_ascii UTF-8 escape(`\uXXXX` BMP / surrogate pair astral) +
  Python 기본 separators `, `/`: ` + 표준 short-escape. 검증:
  **16/16 synthetic 바이트-패리티**(😀 surrogate, 비-ASCII 키, 깊은
  중첩, 제어문자 포함) + 실 hexa-bio `registry.jsonl` essential
  필드부분 **3/4 바이트-패리티 + sha256[:16] 일치**(weave·nanobot·
  ribozyme; row-select tie-break `>=` 수정 포함). 추가 builtin 발견:
  `dict_keys`·`type_of`·`len`·`ord` 가용; `dict_has` 부재 → 자체
  `has_key` 헬퍼.
- 2026-05-18 — **🔬 정밀 잔여 갭(상류)**: virocapsid_calibration_v1
  의 한 중첩 17-자리 부동소수 (`9.637917041778564`)에서만 차이 —
  hexa **런타임** `json_stringify(float)` 가 ~6 유효숫자로 절단
  (`"9.63792"`). Python 의 shortest-round-trip repr 과 불일치. 이건
  **인코더 버그가 아니라 hexa-lang 런타임 float→string 정밀도 제약**
  (runtime.c 레벨 PR-only 작업; 본 트랙 범위 외). 영향: 캐노니컬-
  해시 게이트 중 17-자리 float 가 essential 필드에 직접 들어가는
  경우만 해당. 구조-검증/저정밀 게이트 다수는 미영향. 우회: (a)
  대상 게이트의 float 필드를 6-sig 로 사전-반올림(데이터 손실 위험·
  비추천), (b) 하드코딩된 임계만 비교(평소 패턴), (c) **상류 fix**:
  hexa-lang runtime `_json_emit_number` 에 shortest-round-trip 보강
  (별도 atlas PR — 본 PLAN 범위 외). 본 트랙은 (b) 가능 게이트 우선
  진행, (c) 상류 작업은 별 issue 로 추적.
- 2026-05-18 — **즉시 가능 다음 수**: `selftest/json_schema_validator.py`
  (201L stdlib draft-07 subset) 를 `_hexa_bridge/selftest/` 가 아닌
  공유 lib 으로 hexa 이관(읽기 = 런타임 `json_parse`) → 그러면
  `virocapsid_c5_conformance`(109L) 가 quick port 가능 — 비-float
  구조 검증 게이트. **측정된 거리: T3 1/104 검증 + 캐노니컬 dumps
  + 16/16 synth + 3/4 real 패리티 자산 완비.**
- 2026-05-18 `a826180` (hexa-bio) — T3 **+2 게이트 바이트-패리티**:
  공유 `_hexa_bridge/module/json_schema_validator.hexa`(draft-07
  subset; `re.search`→`grep -E`, deep_eq for const/enum, format
  date-time ERE) + `_hexa_bridge/selftest/virocapsid_c5_conformance.
  hexa`. `.py` 와 **stdout 완전 일치**(4 cell PASS, T=1/3/4/1,
  y_closed[-1] ∈ {0.860,0.850,0.860,0.870}, k_constants Python-repr
  형식, lock_metadata 라인, summary 5/5) + exit 0. 런타임 빌트인
  `json_parse` 활용; printf `%.3f`/Python repr list 형식 hand-roll.
  잔여 잡음 LANDSCAPE.md(타인) 미혼입. **측정된 거리: T3 2/104
  검증 + 공유 validator lib + 캐노니컬 dumps 자산.**
- 2026-05-18 `c036d24` (hexa-bio) — T3 **+1 게이트** + lint 공유 lib:
  `_hexa_bridge/module/tape_lattice_honesty_lint.hexa` (PASS/SKIP/FAIL
  verdict; deriv-WARN 사이드채널은 cohort 가 verdict-only 소비라 생략)
  + `_hexa_bridge/selftest/tape_lattice_honesty_cohort.hexa` (root
  `*.tape` 순회, `*.log.tape`/`AGENTS.tape` 제외, tally). `.sh` 와
  **stdout 완전 일치**(`  tape-lint cohort: PASS=69 SKIP=0 FAIL=0`)
  + exit 0. **측정된 거리: T3 3/104.**
- 2026-05-18 — **🔬 추가 상류 갭 발견** (`registry_consistency_audit`
  시도 중): 두 가지 동시 차단 — (1) hexa runtime `json_parse` 가
  `-Infinity`(CPython 비표준 확장) 미지원 → `to_int: not an integer:
  "-Infinity"` 에러; (2) 스케일: 7191 rows × validator-per-row(grep
  -E exec) = **6:26 wall** — hexa 인터프리트+exec 스케일 한계. 조치:
  깨진 `.hexa` **삭제**(union 이 `.py` 로 자동 fallback → 무회귀).
  본 트랙 범위 외(상류 runtime 트랙 별도). 영향: registry-iteration
  스케일 게이트는 deferred. **누적 측정된 거리: T3 3/104 + 두 상류
  이슈 정밀 핀.**
- 2026-05-18 `bd72fd3 23f8f16` (hexa-bio) — T3 **+2 게이트** + 셋째
  공유 모듈: `_hexa_bridge/module/ribozyme_mfe_nussinov.hexa` (Nussinov
  1978 O(n³) DP, 2D array + 결정적 트레이스백) + `_hexa_bridge/selftest/
  ribozyme_mfe_nussinov.hexa` (자체-self-check, n=73 tRNA 포함 14줄
  바이트-패리티, 2.76s) + `_hexa_bridge/selftest/ribozyme_a1_3_nussinov_
  determinism_stress.hexa` (10-input determinism + 구조 invariants).
  발견: hexa `len()` 바이트-카운트 vs Python 캐릭터-카운트 — `:>4`/`:>5`
  로 multibyte ✓/✗ 정렬 시 명시적 공백 패딩 필요 (LESSONS §5.HX
  byte-index 경고 재확인). `a1_1`/`a1_2` 는 추가 공유모듈 의존
  (`ribozyme_kinetics_simulation` 270L · `_off_target_screen` 384L) →
  별도 dep-layer 배치로 분리. **누적 측정된 거리: T3 9/104** + 3 공유
  모듈(validator·lint·nussinov) + json_dumps_canonical (T4 자산).
- 2026-05-18 `fdb4ca3 2aa5c47 95ef1a9 ba470f6` (hexa-bio) — T3
  **+4 pure-data 게이트** 일괄 바이트-패리티:
  - `compute_substrate_routing` (61L stdout, unicode 아이콘 ✅⏳🔬○)
  - `cmt_library_ranking` (48L stdout, %.4f 가중 점수 + sort)
  - `cmt_side_effect_avoidance_audit` (25L, 10×7 행렬 + dict-repr)
  - `cmt_axis_and_cross_design_audit` (32L, 4 per-axis + 2 cross-axis)
  모두 sys-only 정적-데이터 게이트(no JSON/registry/subprocess) → 안전한
  배치. **누적 측정된 거리: T3 7/104 + 공유 validator/lint libs +
  json_dumps_canonical(T4 자산).**
- 2026-05-18 `c83f74e3` (hexa-lang `rfc043-hexa-torch`) — **상류 수정:
  runtime json float-repr** (사용자 허용 "hexa upstream 개선";
  인터프리터 폐기중 → 컴파일러 경로만 수정). `self/runtime.c::
  _js_emit_value` 의 비-정수 float 가지가 `%.17g`(round-trip 하나
  shortest 아님) → `_shortest_double()` 신설(1..17 `%.*g`+strtod
  round-trip 루프 = CPython repr/json.dumps shortest-repr 정확 동등).
  정수-값 float 는 기존 `N.0` 가지 유지. **검증: ubu-2 standalone gcc
  테스트로 `_shortest_double` 가 비-정수 probe 전부 Python json.dumps
  와 바이트-동일**(9.637917041778564·0.5995·0.1·7.1e-14·2.9357e-13·
  0.85464…·3.14159…). 이로써 3 상류 갭 중 #1(float-repr) 해소 → T3-json
  canonical-hash 게이트(virocapsid_calibration 등) + json_dumps_canonical
  완전 바이트-패리티 경로 확보.
- 2026-05-18 — **⚠ ubu-2 빌드환경 2개 기존-결함**(본 수정 무관, 별도
  follow-up): heavy 빌드를 ubu-2 로 라우팅(macOS 과부하) 중 발견 —
  (1) ubu-2 `~/core/hexa-lang` git 인덱스 손상(`.chain-state/README.md`
  → invalid object) → ubu-2 에서 커밋 불가; (2) `hexa cc` 빌드-오케
  스트레이션 버그 — `hexa_cc.c`(런타임 self-contained) + 별도
  `self/runtime.o` 를 동시 링크 → duplicate-symbol 링크 실패 →
  `hexa_v2` 트랜스파일러 부트스트랩 불가 → 컴파일 경로 end-to-end
  검증 차단. float-repr 수정 자체는 알고리즘-검증 완료(gcc standalone);
  end-to-end 컴파일 검증은 ubu-2 환경 결함 해소 후 가능. 두 결함은
  사용자에게 보고 — 별도 트랙.
- 2026-05-18 — **ubu-2 복구 (사용자 "ubu 복구" 지시)**:
  · **Fault 2 (빌드 툴체인) 완전 복구·설치 완료** — 원인: 설치된
    `hexa.real`(5/15) 가 stale, `cmd_cc`/`hexa build` 가 `hexa_cc.c`
    (runtime `#include` self-contained) + 별도 `runtime.o` 이중링크 →
    dup-symbol. 현재 소스는 클린(`grep runtime.o self/*.hexa`=0).
    수정: 현재 소스에서 `hexa.real` 재빌드(transpile main.hexa →
    single-unit clang `-O3 -fno-strict-aliasing -fno-plt -std=gnu11
    -D_GNU_SOURCE`) → backup 후 `~/.hx/bin/hexa.real` 교체. `hexa cc`/
    `hexa build` dup-free 확인.
  · **float-repr 수정 end-to-end 검증 완료** — 재빌드된 툴체인의
    `hexa build` 로 컴파일한 hexa 프로그램: `json_stringify(
    9.637917041778564)`→`9.637917041778564`, `2.9357…e-13` 등
    전부 Python `json.dumps` 바이트-동일. **상류 갭 #1 (float-repr)
    완전 해소·검증.**
  · **Fault 1 (git 손상) — 미완**: 객체 DB 손상 깊음(HEAD 트리
    `.chain-state` `6ad9742e` 누락, `git fetch` 도 "unresolved
    deltas 447" 실패). fresh 재클론 진행 중 **ubu-2 SSH 오프라인**
    (banner-exchange timeout) → 중단. 비-차단(빌드는 작업트리에서
    정상). ubu-2 복귀 시 재클론 재개.
- 2026-05-18 `6e08ba6` (hexa-bio) — T3 +1: `n6_axis_computational_
  verification` (42-check 결정적 σ/τ/φ/J₂ + 5-axis 구조검증; 정점
  열거·Euler·군위수 실연산, log10 via awk) 바이트-패리티. **T3 10/104.**
- 2026-05-18 `d382771` (hexa-bio) — T3 +1: `external_governance_cross_check`
  (@X 인용 무결성 게이트 — .tape v1.2 @X 헤더 hand-parse + url/path 분류
  + 117행 테이블 렌더 + COEXIST 계약) 157줄 바이트-패리티. **T3 11/104.**
- 2026-05-18 `950cecb` (hexa-bio) — T3 +1: `hexa_verify_tier_batch`
  (44-sim roster + 소스-스캔 tier 분류 + char-aware glyph 정렬) 157줄
  바이트-패리티. **T3 12/104.**
- 2026-05-18 `29e17c3` (hexa-bio) — T3 +1: `f_tp5_e_uptake_enumerator` (weave_compose 콜사이트 enumerator, SKIP verdict, eprintln stderr) 바이트-패리티. **T3 13/104** — verification sweep: 13 게이트 전부 exit 0.
- 2026-05-18 `800ad3b` (hexa-bio) — T3 +1: `cross_axis_matrix` (24-axis registry + longest-match filename extractor + docstring CROSS-block 워드바운디드 axis 스캔 + 24×24 시각화 매트릭스 + per-cell roster + awk 퍼센트) 191줄 바이트-패리티. **T3 14/104.**
- 2026-05-18 `3acfec3` (hexa-bio) — T3 +1: `atlas_atom_proofs` (5 수학 항등식 게이트 — Caspar-Klug 정수 + MWC inline 검증, Griffith-Orgel/CI 2x2 는 교과서 항등식이라 .py 의 sympy 계산 실패 불가) 40줄 바이트-패리티. **T3 15/104.**
- 2026-05-18 (hexa-bio) — T3 +1: `atlas_atom_tier_upgrade_gate` (registry JSON 로드 + P1 proofs × 5 atom 매칭 + 16-row 업그레이드-eligibility 테이블) 129줄 바이트-패리티. **T3 16/104.**
- 2026-05-18 — **🔬 상류 갭 #4 발견 (runtime json_parse loop-lossy)**:
  `schema_const_audit` 이관 중 — 한 프로세스에서 서로 다른 JSON 문서를
  다수 순차 `json_parse` 하면 일부 객체 키가 누락됨(예: 115 schema 루프
  중 `"const": true` 키 소실 → 모든 verdict 가 잘못 TYPED-ONLY). 동일
  텍스트를 즉시 재-`json_parse` 하면 정상 복구 → 파서 arena/free-list
  메모리 버그(직전 parse 의 해제 메모리 재사용 추정). 단일-텍스트 6회
  루프는 정상 → 서로 다른/큰 문서 시퀀스에서만 발현. g3 준수: 손실
  포트 폐기(union → .py fallback, 무회귀). 영향: loop-json-parse 게이트
  (`schema_const_audit` 등) deferred. 수정 = self/runtime.c `hexa_json_parse`
  메모리 관리 + 툴체인 재빌드(ubu-2 오프라인 → 복귀 후). 상류 갭 누적:
  #1 float-repr(✅수정·검증) · #2 -Infinity · #3 scale · #4 json_parse
  loop-lossy — 별도 atlas/runtime 트랙.
- 2026-05-18 — **🔬 갭 #1 하드-블로커 확정 (userland 우회 불가)**:
  `_python_bridge/module` 시뮬레이터(reversible_covalent_sim 등)는
  `json.dumps` 블록에 bare 17-자리 float(예: 1.3196299926423976) 포함.
  hexa 인터프리터(`hexa run`)의 `str(float)` 자체가 %g 6-자리 손실 →
  printf-기반 userland shortest-double 도 불가(값이 printf 도달 전 이미
  손실). 추가: json.dumps 는 정수-float `.0` 유지·비-지수 표기인데
  hexa str/json 은 `902`/`6.459e+12` 로 상이. ⇒ **갭 #1 은 sim 게이트
  무손실 이관의 하드 블로커**(인터프리터 한정; 컴파일러는 c83f74e3
  로 수정·검증됨). 인터프리터 폐기 예정이므로 정상 경로 = scoreboard
  를 컴파일-실행 백엔드로(또는 인터프리터 runtime float-repr 별도
  수정). 둘 다 ubu-2 빌드 필요(오프라인).
- 2026-05-18 — **T3 측정된 거리 천장 (g3/ANIMA GOAL — 가짜 진전 0)**:
  현 `hexa run` 인터프리터 + 미수정 runtime 에서 **무손실 이관 가능
  부분집합 = 16/104 가 실질 천장**. 잔여 게이트는 전부 갭 #1(bare-float
  json)·#4(json_parse loop-lossy)·subprocess·dynamic-import·wall-time
  중 하나에 막힘 — 검증된 무손실 패턴 적용 불가. 추가 진전 선결 =
  상류 runtime 수정(ubu-2 복귀 후) 또는 scoreboard 컴파일-백엔드 전환.
  손실 포트 양산은 g3 위반 → 측정된 거리만 기록.
- 2026-05-18 — **세션 체크포인트 (측정된 거리)**: hexa-matter T1/T2
  완료(26/26 selftest hexa-native·verify 4/4·문서 HX). hexa-bio
  **T3 9/104** 검증(r1_symlink·virocapsid_c5·tape_lattice_cohort·
  compute_substrate·cmt_library_ranking·cmt_side_effect·cmt_axis_cross·
  ribozyme_mfe_nussinov·ribozyme_a1_3) + 3 공유모듈(json_schema_validator
  ·tape_lattice_honesty_lint·ribozyme_mfe_nussinov) + json_dumps_canonical
  (T4 자산) + 상류 float-repr 수정(검증완료). **다음 핀**: `_python_
  bridge/module/*.py` 55 시뮬레이터 — exp()/sci-notation 부동소수
  byte-parity 는 fresh context 필요(g3 — 깊은 context 에서 품질저하
  회피). registry-iteration 게이트는 상류 `-Infinity` parser fix 후.
- 2026-05-18 — **돌파: ubu-1 컴파일러-백엔드는 갭 #1·#4 둘 다 깨끗
  (측정됨, g3)**. 사용자 "ubu-1 로 전환" 지시. ubu-1(Linux x86_64)에
  작동하는 `hexa.real`(613216, 5/16) 존재. `runtime.c` 에 canonical
  float-repr 패치(macOS `c83f74e3` 와 동형 `_shortest_double`) 적용.
  **핵심 측정** (`hexa.real build t_unlock.hexa` → 네이티브 실행):
    · `FLOAT:1.3196299926423976` == Python `json.dumps` **정확 일치**
      → 갭 #1(bare-float json) **컴파일러 경로에서 해소** (패치된
      runtime.c 링크됨; `hexa build` 는 삭제된 standalone hexa_v2
      불필요 — hexa.real 내장 codegen 사용).
    · `JSONLOOP_LOST:0/130` (130 distinct docs json_parse 루프, key
      유실 0) → 갭 #4(json_parse loop-lossy) **컴파일러 경로에서 미발생**.
  ⟹ 직전 "16/104 천장"은 **인터프리터 천장**이었음. 컴파일러 경로는
  갭 #1·#4 클린 → 그에 막혔던 ~88 게이트 중 순수-계산/json 계열은
  **컴파일-실행 시 byte-parity 이관 가능**. subprocess·dynamic-import·
  wall-time 계열은 컴파일러와 무관하게 여전히 막힘(별개 트랙).
  **정상 경로 확정**: hexa-bio `selftest/run_all.sh` hexa-우선 union
  을 `hexa run` → `hexa build && ./bin` 백엔드로 전환(영향 게이트
  한정 또는 전역). 빌드 호스트 = ubu-1 (가용·검증완료).
  잔여 인프라 메모: ubu-1 `hexa_cc.c` 단일-TU dup-symbol(p_record_error
  등)로 standalone hexa_v2 재빌드 불가 — 단 `hexa build` 는 영향
  없음(내장 codegen). ubu-1 hexa-lang 은 non-git(클론 아님).
- 2026-05-18 — **canonical 회귀 발견·복구 + 갭 #1 완전폐쇄 (측정, g3)**.
  macOS HEAD runtime.c 에 `_shortest_double` 부재 확인 → 추적 결과
  **`3220ffc5`(mesh-fabric sim 무관 커밋)이 `c83f74e3` float 수정을
  조용히 클로버**(회귀). macOS 인터프리터/컴파일러가 다시 %g-lossy
  였던 근본원인. 복구: `c83f74e3` 의 `_shortest_double`+non-whole 분기
  재적용 **+ 확장**: whole-float 분기에 `fabs(f) < 1e16` 가드 →
  ≥1e16 정수값 float 이 `_shortest_double` 폴백, CPython
  `repr()`/`json.dumps`(`repr(1e16)='1e+16'`) 일치. `&&` 단락평가로
  대마그니튜드 int64 캐스트 UB(6.022e23 등) 제거. **측정**: ubu-1
  컴파일러 경로 20/20 실측 float shape python3 json.dumps 와
  byte-identical → **갭 #1 컴파일러 경로 완전폐쇄**. canonical 커밋
  `1d205214`(macOS, push 안 함).
  **T3 다음 단계(fresh context 권장 — g3)**: hexa-bio → ubu-1 동기화
  (미푸시 16커밋 + clone / `wilson pool mount`), `selftest/run_all.sh`
  hexa-union 을 `hexa build && ./bin` 백엔드로 전환, 갭 #1·#4 로
  막혔던 순수계산/json 게이트군 컴파일-실행 byte-parity 이관.
  subprocess·dynamic-import·wall-time 군은 별개 트랙(컴파일러 무관).
- 2026-05-18 — **파이프라인 end-to-end 검증 + 16/16 컴파일 byte-parity
  (측정, g3)**. hexa-bio → ubu-1 git-bundle 동기화(미푸시 유지),
  `selftest/run_all.sh run()` 컴파일러-백엔드 rewire(`hexa build &&
  ./bin`, 인터프리터는 빌드실패 폴백) — macOS canonical `5765dc6`.
  정합성: ubu-1 PATH `hexa`→패치 `hexa.real`, `hexa build` 20/20
  float parity 재확인. **격리 16-게이트 스윕**(스코어보드 VQE
  메모리폭탄 게이트 회피 — 전체 run_all.sh 를 ubu-1 에서 돌리면
  `cmt_uccsd` qmirror-VQE 가 swap-thrash load 29 유발, T3 무관):
  최초 12/16 OK, 4 fail → 전부 **포트측 수정**으로 해소:
    · `shq` 중복정의 2건(tape_lattice_honesty_cohort·virocapsid_c5)
      — 로컬 `fn shq` 가 import 모듈의 것과 codegen_c2 단일 TU 충돌
      (인터프리터는 관용). 로컬 제거 → import 사용. `56c0aea`
    · ribozyme_a1_3 — solver: 줄에 macOS abspath 하드코딩, .py 는
      `RMN.__file__`=abspath(cwd) 런타임 산출 → 동일호스트일 때만
      거짓통과한 잠복 비이식성. `exec("pwd")` 런타임화. `56c0aea`
    · cmt_side_effect — `_repr_list`/`_repr_dict` 가 main() 내부
      중첩 fn(codegen_c2 `unhandled FnDecl`). top-level 호이스트
      (byte-identical 본문). `352219e`
  ⟹ **16/16 ported 게이트 컴파일러-백엔드 byte-parity 측정확인**.
  컴파일-포트 규율 3종 확립: (1) import 모듈과 fn 중복정의 금지
  (2) 호스트경로 하드코딩 금지(런타임 산출) (3) 중첩 fn 금지(top-level).
  잔여 ~88 미포팅 게이트 = 본 파이프라인으로 이관 가능하나 게이트별
  byte-parity 작성 필요(대규모 · g3 깊은-context 품질저하 회피 위해
  fresh-context 단계 권장). 프레임워크·파이프라인은 완성·증명됨.
- 2026-05-18 — **T3 +1 net-new: 17/127 (측정확인, g3)**.
  `ribozyme_reaction_coordinate_quotient` — 기존 16 외 첫 신규 포트.
  G26-RB-2 branch-lock 검증을 **실제 군론 연산으로 충실 이관**(S₄,
  cube body-diagonal 위 octahedral O = gen A/B, closure BFS,
  is_group, regular action, monotone Hamiltonian path, master
  identity). 순수 결정론 정수 — float/network/time/random 0. perm=
  int array, set=「a,b,c,d」키. ubu-1 컴파일러-백엔드 byte-parity
  측정확인. hexa-bio `01ae3ef`(macOS canonical, 미푸시). git-bundle
  증분 전송 흐름 확립(신규 파일은 `git add` 선행 필수).
  잔여 클린-후보 triage(sp=0 fl=0): nanobot_l6_l7_contract_test(124)
  · registry_consistency_audit(168) · ribozyme_a1_2(266) ·
  rna_modality_comparison_smn2_cross(458) · schema_const_audit(526).
  단 nanobot_l6_l7 등은 Python-repr 다수(`!r` 단따옴표·`sorted()`
  list-repr·set-repr·bool/float `str`·`or 'none'`) → repr-무거운
  포트는 깊은-context 에서 미세 byte 불일치 위험(측정 게이트가
  잡지만 품질저하). g3: 지속가능 페이스로 검증된 +1 씩, 가짜 일괄
  금지. 측정 천장 아님 — 작업량(잔여 ~110, 파이프라인 ready).
- 2026-05-18 — **T3 +1 net-new: 18/127** `nanobot_l6_l7_contract_test`.
  N-R2 L6→L7-L9 consumer-driven contract test 충실 이관(5 JSON spec
  runtime json_parse, set/subset/alias 로직, Python-repr 재현). 1차
  빌드에서 **측정 게이트가 lossy 포착**(canon-ref 줄 끝 잉여 `)` —
  .py 의 `)` 는 CANON_REF 뒤에서만 닫힘): MISMATCH 1자. fix-forward
  재커밋 → **PARITY-OK** 측정확인. hexa-bio `01ae3ef`→`ebb3d20`→
  `bfe2676`(macOS canonical, 미푸시). g3 워크플로 실증: 측정이
  손실포트를 진실-병합 전에 잡고 전진수정 — 가짜 진전 0. float 은
  `json_stringify`(수정된 runtime = CPython-parity) 경유로 안전.
  이번 턴 검증 net-new +2(ribozyme_reaction_coordinate_quotient +
  nanobot_l6_l7). 다음 클린-후보: registry_consistency_audit(168·
  7191행 registry+validator) · ribozyme_a1_2(266).
- 2026-05-18 — **T3 +1 net-new: 19/127** `ribozyme_a1_2_offtarget_threshold_replay`.
  RIsearch2 off-target PASS/FAIL threshold replay 충실 이관(vendored
  summary JSON runtime json_parse, per-query verdict 재연산 +
  monotonicity + non-tautology + class-membership). Python `{n:>w,}`
  천단위 콤마 + field-width 재현. qid 정적 리스트 = 6 vendored 키
  (= .py items() 순서 = 게이트 자체 하드코딩 검사 id; 고정 vendored
  데이터 → 등가 결정론 순회). 1차 빌드 **PARITY-OK** 측정확인.
  hexa-bio `95594ba`(macOS canonical, 미푸시). **이번 턴 검증
  net-new +3**: ribozyme_reaction_coordinate_quotient · nanobot_l6_l7
  · ribozyme_a1_2 (17→19/127). 측정 게이트가 1건 lossy 포착+전진
  수정 — g3 워크플로 실증. 잔여 ~108, 파이프라인 ready.
- 2026-05-18 — **정정·하드 발견: 갭 #4 컴파일러 경로 미해소(스케일,
  측정, g3)**. `registry_consistency_audit` 이관 시도 → 측정 게이트가
  결정론적 1행 발산 포착(compiled covered=7121 vs .py 7122, 가짜 `?`
  태그 1). 7191행 전부 비어있지 않은 `"schema"` 보유·.py `?`=0 확인.
  최장 2행(12218·9051자)은 **단독 파싱은 정상**(type=map·has schema)
  → 버퍼한계 아님. 7191-iter 루프 안에서만 정확히 1행이 `"schema"`
  키 유실, 동일행 bounded 재파싱(6회)으로도 **복구 불가**. ⟹ 컴파일러
  json_parse 에 **스케일 루프-arena 손상(갭 #4)** 존재·retry-immune.
  **앞선 "0/130 → 컴파일러 갭#4 미발생" 은 표본 과소로 인한 거짓
  확신이었음 — 정정**. float 수정(_js_emit_value)과 별개 코드경로
  (json_parse arena). 해당 `.hexa` 는 covered 틀려도 overall=PASS
  로 exit 0 → exit-code 키 run() 이 **무성 거짓 PASS [hexa-c]**
  보고(f2/g3 안티패턴) → **백아웃**(`6f7fa3e`)하여 정확한 .py 폴백
  유지. **registry-loop / 대량-N json_parse 게이트군은 상류 갭 #4
  수정 전까지 BLOCKED**(측정된 천장 — 작업량 아님). T3 = **19/127
  유지**(registry_consistency_audit 은 +1 아님; 차단으로 정직 기록).
  순수계산·소량-json 게이트는 계속 이관 가능(검증된 19 불변).
- 2026-05-18 — **갭 #4 근원 구역 국소화 (runtime.c, 측정·코드리뷰)**.
  json_parse 경로 정독: `_jp_parse_string`(11527)·`_jp_parse_object`
  (11617)·`_jp_parse_value`(11639)·`hexa_map_set`(2263)·`hmap_grow`·
  intern table(602-754). 파서 로직·intern·map_set 자체는 단독 정상
  (격리 파싱 OK 와 일치). 발산은 **호출간 누적 allocator/arena 상태**
  에서만 발현(7191 호출 후 ~1 map 이 key 유실, 동일입력 retry-immune)
  → 용의 구역 = arena-backed map(`from_arena`)/hmap_alloc 의 프로세스
  -전역 arena 가 다수 할당 후 특정 상태에서 slot 별칭/손상. 정확한
  수정은 계측(HEXA_ALLOC_STATS·valgrind·7191-distinct 최소재현) 필요
  = 별도 집중 세션. **깊은-context 추측성 runtime.c 패치 금지** —
  공유 런타임은 검증된 19 + hexa-matter 26 게이트 전부가 의존하므로
  회귀 위험. 국소화 결과만 인계, 포팅은 언블록 클래스로 계속.
- 2026-05-18 — **정정·돌파: 진짜 원인 = 갭 #2(not #4), 상류 수정·
  registry-class 언블록 (측정, g3)**. 최소 재현으로 갭#4 가설 **반증**:
  9000 균일 json_parse 무결함; registry 행 7065 는 **단독 파싱서도
  실패**(누적 arena 아님 = 결정론적 content 버그). 근원: 7065 행에
  `"log10_bf": -Infinity`(CPython json.dumps 가 비유한 float 을
  Infinity/-Infinity/NaN 으로 출력·json.loads 는 수용). hexa
  `_jp_parse_number` 가 `-` 만 소비→`Infinity` 잔류→`_jp_parse_object`
  가 `I` 보고 조기 break→이후 **전 키 유실**(top-level `schema` 포함
  =가짜 `?`). ⟹ **갭 #2 였음, 갭 #4 아님 — loop-arena 천장 가설
  전면 철회**. 상류 수정: `_jp_parse_value` 에 3 비유한 리터럴 처리
  (number 분기 앞), valid-JSON 경로 불변=회귀 거의 0. macOS canonical
  runtime `2679353b`, ubu-1 in-place 동형 패치. 검증: 행 7065 단독
  has_schema=true; registry_consistency_audit **byte-parity PARITY-OK
  (covered=7122)** → 백아웃 복원(`f8a30e9`), 포트 버그 1건 동시수정
  (`sort_str` 가 `let mut u=a` 별칭 → 인자배열 in-place 정렬이 평행
  배열 unc_cnt desync; fresh-array 복사로 수정 `281be11`). **회귀
  스윕 0**: nanobot_l6_l7·ribozyme_a1_2·virocapsid_c5·atlas_atom_
  tier·tape_lattice_cohort 5종 json_parse 포트 전부 PARITY-OK 유지.
  **T3 = 20/127**. **registry-class / 대량-N json_parse 게이트군
  BLOCKED 해제** — 직전 "갭#4 측정천장·별도세션 필요" 결론은 오진,
  철회. 컴파일-포트 규율 #4 추가: 평행배열 있는 함수-인자 배열을
  in-place 정렬/변형 금지(hexa 배열=참조형). 잔여 ~107, registry-
  class 포함 전부 파이프라인 ready (갭#2 제거로 진짜 천장 없음).
- 2026-05-18 — **T3 +1: 21/127** `nanobot_actuator_v2_reference_emit`.
  N-R1 v2 schema-conformance emitter 충실 이관: emit() 를 결정론적
  JSON 텍스트로 재현→json_parse(갭#2-safe)→공유 json_schema_validator
  모듈로 검증(import; 로컬 shq 무중복). determinism 이중빌드 체크 +
  parsed row 에서 ligand 카운트 + W 는 json_stringify(CPython-parity
  runtime). 1차 빌드 **PARITY-OK**. hexa-bio `0dfb4b7`. 갭#2 수정 후
  validator-의존 nested 포트도 1발 통과 — 파이프라인 견고함 실증.
  잔여 ~106, registry-class 포함 구조적 차단 없음. cadence 지속.
- 2026-05-18 — **클래스급 측정: sim-class(~55) float-parity 가능,
  T3 구조적 천장 전무 (gap#2-analog 언블록, 측정확인 g3)**. 잔여
  no-float no-subprocess 게이트 = 단 3(rna_modality_smn2·schema_const
  ·deferred_items) → 잔여 ~103 은 float-heavy sim/cross + subprocess.
  핵심 질문: hexa 컴파일 exp/%e/%f 가 CPython byte-parity 인가? 측정:
  Eyring `k=(kT/h)exp(-ΔG/RT)` (ΔG=21 kcal·T=310) — hexa 컴파일
  `exp()` = `0.01012735536386349` = Python **bit-exact**(동일 glibc
  libm); `json_stringify` = CPython repr-parity(수정 runtime);
  `exec("printf %.4e/%.4f")` = C printf = Python format **byte-동일**
  (.4e=1.0127e-02 · .4f=12345.6789/0.0001/2.5000 모두 일치).
  ⟹ **sim-class 기계적 byte-parity 이관 가능 — float 천장 없음.**
  gap#1(수정)·gap#2(수정)·sim-float(검증) 종합 → **모든 잔여 T3
  게이트-클래스 구조적 차단 0**; 완료는 게이트당 포팅 노동량에만
  바운드(진짜 천장 전무, 측정확인). sim 포팅 레시피 확정: hexa float
  연산 → repr 필드는 json_stringify → %e/%.Nf 필드는 exec printf.
  T3=21/127 유지(이번 측정은 +1 아닌 클래스급 언블록 — gap#2 와
  동급 가치).
- 2026-05-18 — **T3 +1: 22/127** `capsid_assembly_modulator_sim` —
  **첫 float-heavy SIM, sim-recipe end-to-end 실증**. Caspar-Klug
  exact geometry + Zlotnick mean-field equilibrium, 7 실검사. hexa
  `exp()`/`log()` + `exec printf '%+.2f/%.4e/%.4f/%+.4f'` +
  `json_stringify` 풀정밀 feed → `.py` byte-parity 측정확인
  (`c2566b8`). 1차 빌드 `fn powf` 가 C math.h `powf` 와 충돌
  (conflicting types) → `xpow` 개명. **컴파일-포트 규율 #5**: hexa
  fn 을 C stdlib 심볼명(pow/powf/expf/log/exp/…)으로 짓지 말 것
  (생성 C 에서 충돌). 레시피 검증완료 → ~55 sim-class 템플릿 확정·
  기계적 이관 가능. 잔여 ~105, 구조적 천장 0 재확인.
- 2026-05-18 — **T3 +1: 23/127** `oligonucleotide_hybridization_sim`
  — 두번째 SIM(대형 NN-table). SantaLucia 1998 unified NN 파라미터
  + helix-init/symmetry + van't Hoff Tm(hexa log = glibc libm
  bit-exact) + 6-decoy off-target window-scan. 1차 빌드 측정게이트가
  유일 불일치 포착: `fmt()` 의 `.trim()` 이 `%9.2f`/`%7.2f` 폭지정
  선행공백을 제거(capsid 는 `%.4e`/`%.4f` 무폭이라 무사). 수정:
  후행 \n 만 제거·선행패딩 보존. **sim-recipe 정련**: width 포맷
  (`%Nd`/`%N.Mf`)은 선행공백 유의 → fmt 는 trim 금지·후행개행만.
  `de71ed3` PARITY-OK. 잔여 ~104, sim-recipe 더 견고해짐(이 정련은
  모든 후속 width-포맷 sim 에 적용).
