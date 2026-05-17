# RFC-047 — `mc-integrate` 흡수 (`stdlib/mc_integrate/`)

- **상태**: **Active — landed** (2026-05-18)
- **작성일**: 2026-05-18
- **선행**: 헌법 v2 (5 룰) + RFC 044 (qrng absorption pattern) + RFC 046 (sim-universe absorption pattern)
- **흡수 시리즈 #4**: RFC 044 (qrng ✅) → RFC 045 (qmirror ⏸) → RFC 046 (sim-universe ✅) → **RFC 047 (mc-integrate)**
- **사용자 결정 (2026-05-18)**: qrng/qmirror/sim-universe 와 동일 — hexa CLI 통합 + GitHub repo 명 변경 `dancinlab/mc-integrate` → `dancinlab/archive_mc-integrate`
- **영향 영역**: `stdlib/mc_integrate/` (신규) · `self/main.hexa` (mc-integrate dispatch + cmd_help STDLIB CLI 섹션) · `proposals/rfc_047_mc_integrate_absorption.md` (본 문서)

---

## 1. 동기

`~/core/mc-integrate/` v1.0.0 — productized Monte Carlo numerical integrator —
는 hexa-lang stdlib 흡수 대상 (헌법 v2 룰 2 + 룰 3). qrng (RFC 044) / sim-universe
(RFC 046) 와 동일 패턴 적용.

mc-integrate 는 qrng/qmirror "produce → verify" 3-stage 파이프라인의 **verification**
면: qrng/qmirror 가 양자 비트를 생산하고, mc-integrate 의 `compare_rng()` Welch-t
게이트가 그 비트가 주어진 적분기 위에서 classical CSPRNG (urandom) 과 수치적으로
구별 불가능한지 판정한다. qrng/sim-universe 가 stdlib 으로 흡수된 이상 그 verification
면도 동일 트리(`stdlib/`)에 거주해야 SSOT 단일화가 완성된다.

스코프: 단일 엔진 모듈 (1,263 LoC `mc_integrate.hexa`) + 690-LoC subprocess CLI.
sim-universe 의 26-module ensemble 대비 작아 단일 페이즈로 완결.

## 2. 헌법 v2 룰 매핑

| 룰 | 본 RFC 처리 |
|---|---|
| 1 (rodata 시드) | 비해당 — mc-integrate = 응용/도구 (atlas 시드 콘텐츠 아님) |
| 2 (알고리즘 흡수) | LCG (Numerical Recipes) + MC 적분기 4 상수 + Welch-t df-aware critical-t lookup + Wilson–Hilferty t→z p-value + ANU 3-tier 부트스트랩 → `stdlib/mc_integrate/` |
| 3 (메타 frozen) | AGENTS.tape · README · CHANGELOG · CITATION · LICENSE · hexa.toml · install.hexa · docs/ · examples/ · tests/ → `~/core/archive_mc-integrate/` 묘비. GitHub repo `dancinlab/mc-integrate` → `dancinlab/archive_mc-integrate` 명칭 변경 |
| 4 (외부 자원 δ) | ANU 3-tier (paid/free/legacy) live-or-fallback. 키 없으면 `/dev/urandom` → fixed seed. `--rng external` 은 stdlib/qrng router 위임 |
| 5 (overlay) | 비해당 — mc-integrate 는 발견 누적 도구 아님 |

## 3. 아키텍처 — 엔진 + 디스패처 분리

원본 mc-integrate 는 2-파일 구조:
- `mc_integrate/module/mc_integrate.hexa` (1,263 LoC) — 계산 엔진 (standalone program, `main()` + flag parse + sentinel)
- `cli/mc-integrate.hexa` (690 LoC) — subprocess 라우터

흡수 시 (sim-universe `_run_module` 패턴):

| 원본 | 흡수 후 |
|---|---|
| `mc_integrate/module/mc_integrate.hexa` | `stdlib/mc_integrate/engine.hexa` (verbatim — standalone program 보존) |
| `cli/mc-integrate.hexa` | `stdlib/mc_integrate/mc_integrate.hexa` (디스패처 — `hexa mc-integrate` 진입점) |

엔진은 standalone program 그대로 보존 (main + sentinel + flag parse). 디스패처는
서브프로세스 `hexa run engine.hexa` 로 호출해 엔진의 standalone 시맨틱 + sentinel
출력을 손실 없이 전달한다 (RFC 046 sim-universe 와 동일).

원본 CLI 의 `--rng external` 와이어업은 `~/core/qmirror` · `~/core/qrng` dev-checkout
서브프로세스였다. 흡수 후에는 `hexa qrng collect` (RFC 044 stdlib/qrng router) 위임
으로 갱신 — dev-checkout 경로 하드코드 제거.

## 4. CLI 통합 (별도 `tool/` 폐기)

`stdlib/mc_integrate/mc_integrate.hexa` 디스패처 + `self/main.hexa`
`else if sub == "mc-integrate"` 분기. 별도 `tool/hexa_mc_integrate/` 없음.

호출 패턴 (오늘 작동):

```sh
hexa mc-integrate                                       # default = full self-test
hexa mc-integrate estimate --constant catalan -N 100000 --rng urandom
hexa mc-integrate estimate --constant zeta3 -N 1000000 --rng external
hexa mc-integrate compare --compare catalan -N 50000 --trials 6 --rng-a anu --rng-b urandom
hexa mc-integrate self-test                             # F2-F5 + G1-G6 + H1-H3
hexa mc-integrate status                                # offline ANU-tier probe
hexa mc-integrate chain                                 # 3-stage wire-up resolution
hexa mc-integrate probe-anu                             # live ANU tier probe (uses quota)
hexa mc-integrate --help, -h
hexa mc-integrate --version, -v
```

`hexa --help` 의 STDLIB CLI 섹션에 mc-integrate 8-subcommand 표면 노출.

원본 690-LoC subprocess CLI 는 `~/core/archive_mc-integrate/cli/mc-integrate.hexa`
묘비에 freeze.

## 5. 흡수 범위

```
+ stdlib/mc_integrate/                  (신규 디렉토리)
+ stdlib/mc_integrate/engine.hexa       (1,263 LoC — 원본 module verbatim)
+ stdlib/mc_integrate/mc_integrate.hexa (디스패처 — hexa mc-integrate 진입점)
+ stdlib/mc_integrate/README.md         (흡수 README)
+ stdlib/test/test_mc_integrate.hexa    (selftest sentinel)
~ self/main.hexa                        (mc-integrate dispatch + cmd_help STDLIB CLI)
+ proposals/rfc_047_mc_integrate_absorption.md (본 문서)

  (frozen archive — ~/core/archive_mc-integrate/)
  AGENTS.tape · CHANGELOG.md · README.md · CITATION.cff · LICENSE ·
  RELEASE_NOTES_v1.0.0.md · TAPE-AUDIT.md · hexa.toml · install.hexa ·
  cli/ · docs/ · examples/ · tests/ · state/   →   재해석 없음 (헌법 v2 룰 3)
```

## 6. 호환성

- 원본 `dancinlab/mc-integrate` GitHub repo → `dancinlab/archive_mc-integrate` 명칭 변경
- 외부 consumer 없음 (mc-integrate 는 자체 응용; hexa-lang 외 consumer 미확인)
- `stdlib/qrng/` (RFC 044) 와 cross-reference: `--rng external` 가 `hexa qrng collect`
  위임 — 단방향 의존 (mc_integrate → qrng)
- 공개 API (`estimate_constant` · `compare_rng`) 시그너처 변경 없음 — engine.hexa verbatim

## 7. Falsifier (인수 조건)

1. **F-RFC047-PARSE**: `hexa parse stdlib/mc_integrate/engine.hexa` + `hexa parse stdlib/mc_integrate/mc_integrate.hexa` 종료코드 0.
2. **F-RFC047-BUILD**: `hexa build stdlib/mc_integrate/mc_integrate.hexa -o /tmp/mci` 종료코드 0, 바이너리 생성.
3. **F-RFC047-CLI**: 디스패처 `--help` 가 8-subcommand + 4 named constant + 7 RNG selector 표 출력. `--version` 가 `1.0.0` 출력.
4. **F-RFC047-ESTIMATE**: `mc-integrate estimate --constant catalan -N 2000 --rng urandom` 가 엔진 서브프로세스 경유 `__MC_INTEGRATE__ PASS` sentinel 출력.
5. **F-RFC047-DISPATCH**: `hexa parse self/main.hexa` 종료코드 0. `else if sub == "mc-integrate"` 분기 + cmd_help STDLIB CLI 섹션 존재.
6. **F-RFC047-ARCHIVE**: `~/core/archive_mc-integrate/` 존재. GitHub repo `dancinlab/archive_mc-integrate` 로 명칭 변경 확인.
7. **F-RFC047-RFC-DOC**: 본 RFC 문서 `proposals/rfc_047_mc_integrate_absorption.md` 존재.

## 8. Risks

- **R1** — 엔진 서브프로세스 호출이 `hexa run` (interp) 경유 → 대규모 N 에서 macOS memcap 위험. **Mitigation**: 엔진은 self-test 기본 N 범위에서 검증. 대규모 N 은 원격 (wilson pool) 권장.
- **R2** — `--rng external` 의 stdlib/qrng 위임이 qrng router 출력 포맷 (`QRNG_HEX:`) 에 의존. **Mitigation**: 포맷 불일치 시 inline 3-tier ANU → urandom 폴백 (디스패처 fall-through).

---

**Co-author**: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
