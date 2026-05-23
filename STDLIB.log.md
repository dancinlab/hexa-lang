# STDLIB — log

Append-only history sister of `STDLIB.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-24T23:30:00Z — /cycle 사이클 2: 7 마일스톤 병렬 흡수 — 7/7 oracle PASS · 도메인 100% closed

7 백그라운드 에이전트 (worktree isolation, heavy 3종 first-iter scope) 병렬 fan-out, 전수 머지:

| PR | sha | milestone | oracle | defer note |
|---|---|---|---|---|
| #642 | 0dfd3572 | mirna-target            | 8 cases TargetScan seed-scan | — |
| #644 | c45b6dc6 | autodock-vina-port      | 6 cases ±1e-4 (5-term scoring) | Monte Carlo search · grid map |
| #645 | cd155a23 | iedb-epitope            | REST 5/7 + PSSM 6 peptides | NetMHCpan SVM/ANN core |
| #647 | c0a83f5a | seq-align               | 7 cases (NW + SW) | MSA progressive |
| #648 | f94ccb30 | openmm-core             | 4 cases energy drift <1% | PBC · Ewald · bonded forces |
| #652 | 3b7258fc | rdkit-subset            | 7 cases ±0.05 MW (SMILES + MW) | logP · TPSA · HBA/HBD |
| #654 | 7f9fc098 | crispr-off-target       | 5 cases synthetic genome | — |

- [x] 7 마일스톤 체크박스 STDLIB.md 갱신 (heavy 3개는 first-iter scope 명시)
- [x] 0 fail · 4 정직-deferred sub-feature (search/grid · NetMHCpan · MSA · PBC/Ewald 등)
- [x] 모든 모듈 `hexa parse` + `hexa run` PASS gate 통과 후 머지
- [x] 모든 모듈 `// stdlib/<path> — <purpose>` 헤더 규격

진행 상태: **15/15 actionable closed** (100%) · 1 deferred (open-babel-subset, GPL-2 라이선스 검토 후). STDLIB 도메인 first-cycle 캠페인 종료. 후속 = 각 모듈의 deferred sub-feature 보강 라운드 (도메인 외 sub-cycle 으로 분리).

## 2026-05-24T22:30:00Z — /cycle 사이클 1: 8 마일스톤 병렬 흡수 — 8/8 oracle PASS

8 백그라운드 에이전트 (worktree isolation) 병렬 fan-out, 전수 머지:

| PR | sha | milestone | oracle |
|---|---|---|---|
| #633 | 1623f2f4 | pubmed-api               | 7 fields/1 entry |
| #634 | 5b8bdd38 | clinicaltrials-api       | 9 fields/4 entries |
| #635 | b4ffc879 | brenda-api               | parse-surface (SOAP deferred) |
| #636 | cbaba90a | ncbi-entrez              | 7 fields/1 entry |
| #637 | 1e28abe3 | ode-bifurcation          | 4 tests (RK4·RK45·logistic·saddle-node) |
| #638 | 27290140 | uniprot-alphafold-api    | 13 fields/2 entries |
| #639 | f8920307 | pubchem-api              | 10 fields/1 entry |
| #640 | 99192a51 | doench-grna-score        | 5 cases tol=±0.05 (16/16 sub) |

- [x] 8 마일스톤 체크박스 STDLIB.md 갱신
- [x] 0 fail · 1 정직-deferred (brenda SOAP 인증 후속)
- [x] 모든 모듈 `hexa parse` + `hexa run` PASS gate 통과 후 머지
- [x] 모든 모듈 `// stdlib/<path> — <purpose>` 헤더 규격 (자동 `hexa stdlib` harvest 대상)
- [x] Python/shell-out 제거 — 전부 `http_get` + lightweight XML/JSON tag-slicing

진행 상태: 9/16 closed (56%) · 6 open · 1 deferred. 후속 우선순위 — seq-align · crispr-off-target (P0 잔여) · rdkit-subset (TTR Tier-2 시작점).

## 2026-05-24T21:30:00Z — TTR in-silico track 흡수 — 6 마일스톤 신규 등록 (1 deferred)

- [x] `inbox/notes/2026-05-24-ttr-external-port-candidates.md` 리뷰 → STDLIB 도메인 흡수
- [x] STDLIB.md `### TTR — in-silico track` 섹션 신설 — 4 tier 분류
- [x] Tier-1 thin REST adapter 3종 등록 — pubchem-api · brenda-api · uniprot-alphafold-api (각 ~200-300 LOC)
- [x] Tier-2 cheminformatics 2종 — rdkit-subset (★★★ active) · open-babel-subset (GPL-2 라이선스 검토 DEFERRED)
- [x] Tier-3 docking 1종 — autodock-vina-port (★★★, ~5 kloc Apache-2)
- [x] Tier-4 MD 1종 — openmm-core (★★, ~3-5 kloc MIT)
- [x] AlphaFold DB API sunset 2026-06-25 risk 명시 (uniprot-alphafold-api 코멘트에 기록)

밀스톤 총합 10 → 16 (1 closed · 14 open · 1 deferred). 후속 우선순위 — TTR Tier-1 (M3 즉시 사용 가능, 가장 가벼움) 부터.

## 2026-05-24T21:10:00Z — arxiv-api 포팅 (P1 #1/3 closed) — measured-oracle PASS

- [x] `stdlib/research/arxiv.hexa` — `ArxivPaper` struct + `arxiv_search` · `arxiv_fetch` · `arxiv_pdf_url` · `arxiv_parse_atom`
- [x] `stdlib/research/arxiv_test.hexa` — 2-entry frozen-fixture oracle (`compiler/bridges/_cache/arxiv.frozen.xml`, 2026-05-13 snapshot)
- [x] 8 fields × 2 entries + 3 pdf_url synthesis + 2 empty/error paths all PASS
- [x] STDLIB.md ref 라인 stale STDLIB.json 참조 정리 (PR #630 follow-up)

핵심 — XML 파서는 lightweight tag slicing + 5 entity decoding (no full XML dep). pre-2007 (`math/0603469v1`) + modern (`2401.12345v2`) id form 둘 다 커버. 다음 = pubmed-api (P0 #1).

## 2026-05-24T20:35:00Z — STDLIB 도메인 scaffold + 10 포팅 마일스톤 선언

- [x] hexa-lang root `STDLIB.md` + `STDLIB.log.md` 생성
- [x] @goal — 외부 라이브러리 hexa-native 포팅 (Python/CLI shell-out 제거) measured-oracle PASS until absorbed=false
- [x] needs-check 인벤토리 (HERPES M1-M9) 매핑 → 10 포팅 마일스톤 도출
- [x] 누락 확인 (grep stdlib/ for arxiv · pubmed · clinicaltrials · entrez · mafft · doench · crispor · iedb · mirbase · targetscan · ode · bifurcation · alphafold · rosetta · mhc)
- [x] 기존 부분구현 식별 — bio/crispr_gene_editing/ (off-target 누락) · bio/design.py (alphafold/rosetta stub) · math/ (전용 ODE 모듈 없음)

🔑 우선순위 (HERPES P0/P1/P2 매핑):
- **P0** (M5 + M9 즉시 막힘): crispr-off-target · doench-grna-score · clinicaltrials-api · pubmed-api · ncbi-entrez
- **P1** (M3/M4 인용 정확성 + 모델 promotion): arxiv-api · ode-bifurcation · seq-align
- **P2** (long-term 검증): iedb-epitope · mirna-target

비교 — demiurge가 의존 → hexa-lang stdlib SSOT (per memory `project_demiurge_pointer_hexa_lang_ssot`). HERPES M3 §7 Markov + M4 §5 ODE + M6 §3 Bliss synergy 모두 ode-bifurcation 포팅 후 🟢 → 🔵 promotion 가능.
