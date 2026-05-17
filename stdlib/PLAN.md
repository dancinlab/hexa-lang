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
- **T3** ⏳ hexa-bio stdlib-only 모듈 (전수조사 후 식별)
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
