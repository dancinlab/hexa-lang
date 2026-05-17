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
