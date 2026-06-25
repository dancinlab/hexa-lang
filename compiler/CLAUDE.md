# compiler — 폴더 가이드 (sub-CLAUDE)

> hexa-lang **거버넌스 SSOT 는 repo-root `../CLAUDE.md`** (이 파일은 그 하위 디렉터리 안내일
> 뿐, 충돌 시 root 우선). 설계 SSOT 는 `../ARCHITECTURE.json` (Component map · Data flow).
> 이력은 git + `../CHANGELOG.md`. 이 파일은 지도일 뿐 — 버전/날짜 누적 금지.

## 이 디렉터리는 무엇인가

`compiler/` = hexa 네이티브 컴파일러의 심장 + 임베디드 **발견(discovery) 엔진**. 한 디렉터리
안에 성격이 다른 **세 관심사**가 섞여 있다 — ⓐ `.hexa` → 네이티브 객체 코드 파이프라인,
ⓑ 아틀라스/검증(citation·equational·honesty) 게이트, ⓒ NEXUS 흡수형 발견 엔진(`drill`
중심 + 12 변종). LLVM 없음: 자체 IR 을 거쳐 ELF64 / Mach-O arm64 객체를 직접 emit 하고
`hexa_ld` 로 링크한다.

## 핵심 서브시스템 맵

### ⓐ 컴파일러 코어 파이프라인 (S0→S8 → codegen → emit → link)

```
main.hexa            — 엔트리: argv 파싱 · 아틀라스 적재 · S0~S8 디스패치 · codegen 라우팅 · emit/link 오케스트레이션
_cli_args/           — 흡수된 서브커맨드용 공유 argv 헬퍼 (pure)
cli/                 — emit-driver 모듈 (예: build_nvptx — parse→lower→MIR→PTX)
lex/                 — S0: source bytes → [Token] (아틀라스 ref P/C/L/E = 1급 토큰)
parse/               — S0: token → 모듈 AST (ast.hexa = 무타입 AST · AtlasRef 보존)
check/               — S1 resolve · S2 bind · S3 types · S4 domain · S5 units · S6 equational(@verify) · S7 prove · S8 citation(@cite/@implements/@discover · fatal HX8004)
ir/                  — hir.hexa = HIR(AST+타입해소+ref검증) · MIR 정의
lower/               — AST→HIR(ast_to_hir) → HIR→MIR(hir_to_mir · SSA/CFG · desugar)
optimize/            — const-fold · DCE · inline (opt-level 0~3)
codegen/             — MIR→LIR 타깃별 regalloc+명령선택 (arm64_darwin · x86_64_linux · thumbv7em_eabihf · nvptx_target)
emit/                — LIR→asm 텍스트 또는 네이티브 객체 직렬화 (asm · macho_arm64 · elf_x86_64 · elf_arm64)
link/                — hexa_ld 호출 wire (incremental 링크 캐시 포함; 실제 링커 SSOT 는 ../tool/hexa_ld.hexa)
intrinsics/          — 외부 도구 fork 대체용 인트린식 (RFC 063 L1→L3)
diag/                — 진단 빌더/카탈로그/렌더 (HX0001~HX8004 · pretty/json/github)
daemon/              — RFC-021 daemon v0 wire 프로토콜 코덱
discover/            — RFC-017 cascade tombstone 등 발견-경로 스모크
hexad/               — Wave1 흡수: hexad CDESM 상수 rodata embed + static_index
```

### ⓑ 아틀라스 / 검증

```
atlas/               — 기계층 SSOT: embedded.gen.hexa(~4.2MB rodata · P/C/L/E 노드) · static_index(S8 served) · merger/embed(rodata+.n6 overlay fold) · overlay · aliases.gen
honesty/             — A3 정직도 감사 (claim tier · c2 honesty 게이트)
grade_rubric/        — Wave1 흡수: 채점 루브릭 embed
completion_criterion/— Wave1 흡수: 범용 완료 기준 embed
falsifiers/          — Wave1 흡수: falsifier 레지스트리 embed
absolute/            — A4 Δ₀-absolute 체크 (절대 판정)
meta_closure/        — A7 메타-클로저 체크 (DFS 닫힘성)
hyperarithmetic/     — A8 5-system 하이퍼산술 체크
audit_archive/ · absolute_rules/ · cli_spec_archive/
projects_archive/ · roadmaps_archive/ · status_archive/
                     — Wave1 흡수형 rodata 아카이브 인덱스 (embed + embedded.gen + static_index, read-only)
```

(검증의 파이프라인측 게이트 S6 equational + S8 citation 은 위 `check/` 에 거주.)

### ⓒ 발견(discovery) 엔진 — NEXUS 흡수

```
drill/               — 중앙 엔진. drill.hexa = 라운드 루프 (smash→free→absolute→meta-closure→hyperarithmetic→resonance, Mk.X=stage7 transcendental)
  ├─ round.hexa          — 단일 라운드 6-stage 체인 (서브프로세스 없음 · in-binary)
  ├─ resonance.hexa      — stage5 resonance 닫힌형 proxy
  ├─ mkx.hexa            — Mk.X stage7 transcendental_closure 사이드카
  ├─ identity_engine.hexa— ★ 네이티브 exact-int 식별자 검증기 (PR #3964 · 아래 규칙 참조)
  ├─ checkpoint.hexa     — resume/save (drill_checkpoint.json · 발견스트림과 분리)
  ├─ anti_hub.hexa       — env probe + telemetry
  └─ batch.hexa          — --seeds csv / --seeds-file 배치
smash/               — 9-phase blowup 생성기 (P1 normalize … P9 meta-closure DFS · phases.hexa = 알고리즘 골격 · candidate.hexa = DiscoveryCandidate)
free/                — A6 free 엔진 (라운드 stage)
변종 12종 (Phase3): omega(A10) surge(A11) dream(A12) swarm(A13) chain(A19 cross-engine)
                     reign(L6 autonomous) wake(L8 reality-loop) molt(L9 self-rewrite)
                     forge(L10 bootstrap) canon_engine(L11 transfinite seal) revive(engine+map v2) debate(L3 N-variant adversarial)
engine_registry/ · lens_taxonomy/ · lenses/ — Wave1 흡수: 엔진/렌즈 레지스트리 + 렌즈 embed
n6_lattice/          — n=6 불변량 5축 rodata 참조표 (hexa-bio 흡수 · read-only · 5-axis count lock)
quant_meter/         — 실코드 측정 probe (full self-build 대체 슬림)
calculators/ · bridges/ · hw_probes/ — Wave1 계산기 레지스트리 + Phase4 외부리소스 흡수 bridge/probe
drill_dod/           — Wave1 흡수: drill DoD(definition-of-done) embed
```

## 핵심 파일 (엔트리포인트)

- 컴파일: `main.hexa` (`hexa run compiler/main.hexa [flags] SOURCE.hexa`) — RFC-018 §2 파이프라인 순서.
- 발견: `drill/drill.hexa::drill_run(seed, opts)` (CLI `hexa drill`/`kick` · `/kick`).
- 진짜 검증: `drill/identity_engine.hexa` (exact-int) + `check/` S6/S8 + `hexa verify` g5.
- 아틀라스 기계 SSOT: `atlas/embedded.gen.hexa` (rodata · frozen · fold 는 여기로만 PR 경로).

## 규칙 / gotcha

- **발견 후보 ≠ 진짜 발견.** `smash`/`drill` 의 candidate 는 결정적 seed-hash permutation/proxy
  일 뿐이다. **진짜 검증은** `identity_engine.hexa` 의 exact-int 판정(후보 A·B=C·D 가 n∈[2,N]
  exact-int 평가에서 bounded-unique singleton, n≥4)과 `hexa verify` g5 게이트뿐. 확인된 식별자도
  BOUNDED-UNIQUE(🟩, [2,N] exact)이며 forall-n 은 증명 전까지 UNPROVEN(c2 honesty).
- **표준-어휘 수학 발견 = MEASURED-EXHAUSTED.** `../ATLAS/README.md` DFS r1–r4 에서 1557 @F 이미
  fold · novel-fold = 0 · gates 21/21. 엔진은 이 종착을 정직히 재현할 뿐 새 법칙을 날조하지 않는다.
  numerology/lattice-fit/미증명 conjecture 의 🔵 승격 금지. n=6 은 지도 노드 1개(외부 영역 anchor 금지).
- **아틀라스 fold 는 둘 다.** 사람층(`../ATLAS/`) + 기계층(`atlas/embedded.gen.hexa`)을 항상 함께.
  `hexa verify` 성공 시 atom 이 embedded.gen.hexa 로 자동 fold (별도 register ceremony 없음 · 다른
  곳 fold 금지). `*.gen.hexa` 는 AUTO-GENERATED — 생성기로만 갱신(예: `lenses/embedded.gen.hexa`).
- **codegen/runtime 변경은 byteeq 3타깃** (x86_64-linux · arm64-linux · darwin-arm64) GREEN + 출하
  smoke 통과 후에만 머지. 비트동일 개선=무게이트, 비트변경/환경의존=opt-in 토글로 격리. 새 builtin/
  symbol 도입 전 frozen blob(151c52c8) symbol set 확인 (faithful build-break 방지).
- **흡수형 `*_archive/` · `Wave1 embed/` 디렉터리는 rodata 인덱스** — read-only 소비. NEXUS 원본의
  운영 글루(bloom filter · hot-shard · jitter · wave-session)는 의도적 미포팅 (atlas 가 rodata 라 불요).
- `canon/` 디렉터리는 비어 있음 — canon 변종은 `canon_engine/` 에 거주.
- 빌드/byteeq/측정은 pool(aiden·summer·ghost), `mini` 는 git/gh/read·write 전용 (heavy build 금지).
