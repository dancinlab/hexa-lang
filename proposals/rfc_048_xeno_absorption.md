# RFC-048 — `xeno` 흡수 (`stdlib/xeno/`)

- **상태**: **Active — landed** (2026-05-18)
- **작성일**: 2026-05-18
- **선행**: 헌법 v2 (5 룰) + RFC 044 (qrng) · RFC 046 (sim-universe) · RFC 047 (mc-integrate) 흡수 패턴
- **흡수 시리즈 #5**: RFC 044 (qrng ✅) → RFC 046 (sim-universe ✅) → RFC 047 (mc-integrate ✅) → **RFC 048 (xeno)**
- **사용자 결정 (2026-05-18)**: `~/core/xeno` 전체(CLI + 문서 포함)를 stdlib 로 **완전 흡수** → GitHub repo `dancinlab/xeno` → `dancinlab/archive_xeno` 명칭 변경 → 로컬 폴더 `~/core/xeno` **삭제**
- **영향 영역**: `stdlib/xeno/` (신규, 643 파일 / ~6.8MB) · `self/main.hexa` (xeno dispatch + cmd_help STDLIB CLI) · `proposals/rfc_048_xeno_absorption.md` (본 문서)

---

## 1. 동기

`~/core/xeno/` v0.1.0 — Tier C 비-GPU exotic compute substrate SSOT (silicon
neuromorphic AKIDA/Loihi3/Northpole + biological organoid FinalSpark/Cortical
Labs + quantum IonQ + QRNG) — 를 hexa-lang stdlib 으로 완전 흡수한다.

qrng/sim-universe/mc-integrate 와 구조가 다르다: xeno 는 깔끔한 hexa 계산
라이브러리가 아니라 **bash CLI + Python 오케스트레이터 + 연구 산출물 SSOT**다.
hexa.toml provenance: "extracted 2026-05-08 from 4 source repos (anima + nexus
+ hive + hexa-brain)". 즉 xeno 자체가 4개 repo 의 substrate 연구 집약본이다.

사용자 지시는 명확하다 — CLI·로드맵·README·docs 까지 전부 stdlib 로 흡수하고,
로컬 폴더는 삭제, GitHub repo 는 `archive_xeno` 묘비로 보존.

## 2. 헌법 v2 룰 매핑

| 룰 | 본 RFC 처리 |
|---|---|
| 1 (rodata 시드) | 비해당 — xeno = 응용/SSOT (atlas 시드 콘텐츠 아님) |
| 2 (알고리즘/CLI 흡수) | bash `bin/xeno` (8-topic CLI) → hexa-native `stdlib/xeno/xeno.hexa` 재작성. 7-substrate 로드맵 → `stdlib/xeno/roadmaps/` |
| 3 (메타 frozen) | 사용자 지시로 **전수 흡수** (archive 분리 아님): README · docs/ (63) · design/ (omega witnesses) · n6/ (atlas appends) · scripts/ (Python falsifier/cycle) · state/ (evidence 53 dir) · AGENTS.tape · hexa.toml 모두 `stdlib/xeno/` 에 verbatim. GitHub `archive_xeno` 가 추가 묘비 |
| 4 (외부 자원 δ) | sister repo (anima/nexus/hive/hexa-brain) 는 런타임 path probe + raw-91 fail-loud. Akida 칩/Cloud probe 도 동일 |
| 5 (overlay) | 비해당 |

## 3. 아키텍처 — bash CLI → hexa-native 디스패처

원본 `bin/xeno` 는 bash (8 topic: status/connect/invoke/fallback/list/roadmap/
falsifier/cycle). 원본 `cli/run.hexa` 는 bin/xeno 로 위임하는 thin hexa shim.

흡수 시 **hexa-native 재작성** (HEXA-NATIVE-ONLY 정합):

- `stdlib/xeno/xeno.hexa` — `hexa xeno` 진입점. 8 topic 을 hexa 로 재구현.
  status/list/roadmap/fallback/connect/invoke 는 self-contained hexa.
  falsifier/cycle 은 Python machinery (`scripts/akida/...`) 를 서브프로세스
  dispatch — `XENO_ROOT` env, 없으면 stdlib/xeno/ 자체(scripts/ 흡수됨),
  python3 부재 시 exit 91 fail-loud (xeno raw-91 doctrine 보존).
- 원본 bash `bin/xeno` + `cli/run.hexa` 는 `stdlib/xeno/` 에 verbatim 보존
  (역사 산출물; 활성 CLI 는 hexa `xeno.hexa`).

exit code: 0 success · 1 subcommand error · 2 unknown topic · 91 unreachable
(raw 91 honest C3 fail-loud — silent skip BANNED, xeno @D g3 보존).

## 4. CLI 통합

`self/main.hexa` `else if sub == "xeno"` 분기 — `cmd_run(stdlib/xeno/xeno.hexa,
args[3..])`. `hexa --help` STDLIB CLI 섹션에 xeno 8-topic 노출.

호출 패턴 (오늘 작동):

```sh
hexa xeno                              # status (default)
hexa xeno status                       # health + sister-repo reachability + 7-substrate inventory
hexa xeno list                         # substrate inventory
hexa xeno roadmap akida                # substrate roadmap
hexa xeno connect anima                # sister-repo bridge probe
hexa xeno invoke nexus status          # sister-repo CLI passthrough
hexa xeno fallback                     # degraded-mode info
hexa xeno falsifier list               # 12-falsifier inventory
hexa xeno falsifier run F-L7           # dispatch Python harness (needs python3)
hexa xeno cycle status                 # Akida cycle status
hexa xeno --help, -h / --version, -v
```

## 5. 흡수 범위

```
+ stdlib/xeno/                          (신규, 643 파일 / ~6.8MB)
+ stdlib/xeno/xeno.hexa                 (hexa-native CLI 디스패처 — 신규 작성)
+ stdlib/xeno/roadmaps/                 (10 substrate roadmap, verbatim)
+ stdlib/xeno/README.md                 (원본 + 흡수 배너)
+ stdlib/xeno/docs/                     (63 문서, verbatim)
+ stdlib/xeno/design/ n6/ scripts/ state/ anima_physics_origin/ mirror/ tool/ bin/ cli/
+ stdlib/xeno/AGENTS.tape hexa.toml install.hexa CITATION.cff TAPE-AUDIT.md
~ self/main.hexa                        (xeno dispatch + cmd_help STDLIB CLI)
+ proposals/rfc_048_xeno_absorption.md  (본 문서)
- stdlib/xeno/CLAUDE.md                 (원본 symlink 제외 — 중첩 CLAUDE.md auto-discovery 오염 방지; AGENTS.tape 가 내용 보존)
```

원본 `~/core/xeno/` 로컬 폴더는 흡수 후 **삭제**. GitHub repo `dancinlab/xeno`
→ `dancinlab/archive_xeno` 명칭 변경 (역사 묘비; .git 히스토리 보존).

## 6. 호환성

- xeno 는 외부 consumer 없음 (자체 SSOT; hexa-lang 외 consumer 미확인)
- akida hw_probe (`compiler/hw_probes/akida.hexa`) 와 qrng (`stdlib/qrng/`) 는
  이미 흡수됨 — xeno 의 substrate 콘텐츠와 중복이 아니라 보완 (probe vs SSOT)
- `hx install xeno` 패키지 경로 폐기 — `hexa xeno` 서브커맨드로 대체

## 7. Falsifier (인수 조건)

1. **F-RFC048-PARSE**: `hexa parse stdlib/xeno/xeno.hexa` 종료코드 0.
2. **F-RFC048-BUILD**: `hexa build stdlib/xeno/xeno.hexa -o /tmp/xeno` 종료코드 0.
3. **F-RFC048-CLI**: 디스패처 `list` 가 7-substrate 표, `roadmap akida` 가 .roadmap.akida 내용, `--version` 가 `0.1.0` 출력.
4. **F-RFC048-DISPATCH**: `hexa parse self/main.hexa` 종료코드 0. `else if sub == "xeno"` 분기 + cmd_help STDLIB CLI 섹션 존재.
5. **F-RFC048-ROADMAPS**: `stdlib/xeno/roadmaps/.roadmap.{akida,loihi3,northpole,finalspark,cortical_labs,ionq,qrng}` 7개 존재.
6. **F-RFC048-DOCS**: `stdlib/xeno/docs/` 63 문서 + `stdlib/xeno/README.md` 흡수.
7. **F-RFC048-ARCHIVE**: GitHub repo `dancinlab/archive_xeno` 명칭 변경 확인. 로컬 `~/core/xeno` 삭제 확인.
8. **F-RFC048-RFC-DOC**: 본 RFC 문서 존재.

## 8. Risks

- **R1** — 중첩 `hexa.toml` (`stdlib/xeno/hexa.toml`) 가 hexa-lang 빌드의 패키지 해석을 교란. **Mitigation**: 빌드 게이트 `hexa build self/main.hexa` 로 검증; 교란 시 rename.
- **R2** — falsifier/cycle 의 Python machinery 가 `python3` 의존 → hexa-lang 의 hexa-native 순수성과 긴장. **Mitigation**: Python 은 디스패처가 호출하는 외부 자원일 뿐 (codegen backend 아님); 부재 시 exit 91 fail-loud. g5/f2 위반 아님.
- **R3** — 로컬 폴더 삭제는 비가역. **Mitigation**: 삭제 전 `git status` clean + unpushed commit 0 확인; GitHub `archive_xeno` 가 .git 히스토리 전수 보존.

---

**Co-author**: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
