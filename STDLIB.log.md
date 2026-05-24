# STDLIB — log

Append-only history sister of `STDLIB.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-25T08:00:00Z — /cycle 사이클 4: open-babel-subset GPL-2 회피 closure — STDLIB 도메인 100% closed

cycle 1+2+3 closure 후 남은 단일 open 마일스톤 = `open-babel-subset` (GPL-2 라이선스 검토 DEFERRED). 사용자 결정 = **B-2 (GPL-2 회피 + scratch 구현)** — rdkit-subset · autodock-vina-port 의 동일 회피-by-reimplementation 패턴.

| PR | sha | milestone | scope | oracle |
|---|---|---|---|---|
| #686 | (squash) | open-babel-subset → babel-free | MOL V2000 + SDF + PDB ATOM/HETATM/CONECT (1184 LOC × 4 파일) | 7 cases PASS · open-babel 자료 참조 0, CTfile + PDB v3.3 공개 spec 만 |

- [x] open-babel-subset 마일스톤 → `stdlib/chem/babel_free/{mol,sdf,pdb,format_io_test}.hexa` (B-2 path)
- [x] `MolAtom/MolBond` struct 는 rdkit_subset 과 의미/단위/index base 달라 별도 정의 (어댑터는 future)
- [x] PR #686 의 코멘트에 CTfile spec URL + PDB v3.3 URL 명시 (provenance)
- [x] STDLIB.md 마일스톤 체크박스 갱신 + 본 로그

진행 상태: **21/21 actionable closed (100%)** · STDLIB 도메인 first-cycle 캠페인 종료.

후속 — 새 milestone 등록은 사용자 결정 대기:
- cycle 3 sub-sub-feature 후보 (rdkit 68-type SMARTS · vina BFGS · iedb ANN · brenda credentials manager · Ertl S/P · SSSR)
- cycle 4 새 inbox/notes/2026-05-25-* 후보 (bindingdb · chembl · drugbank · febio · openfoam · pk-sim 등)
- 다른 도메인 pivot (HEXA_LANG · 등)

## 2026-05-25T05:30:00Z — /cycle 사이클 3: 6 deferred sub-feature 보강 — 6/6 oracle PASS · 정공법 완성도기준

정공법 + 완성도기준 라운드 — cycle 1+2 의 14개 모듈 중 6개에 표시됐던 `※ ... deferred` sub-feature 들을 닫아 모듈 완성도 100% 로. 6 백그라운드 에이전트 (worktree isolation) 병렬 fan-out, 전수 squash 머지.

| PR | sha | milestone | parent | oracle |
|---|---|---|---|---|
| #671 | ced8f7ae | seq-align-msa       | seq-align (PR #647)         | 7 cases (NW dist · NJ tree · profile-profile DP) |
| #672 | a15f526b | vina-search         | autodock-vina-port (PR #644) | 6 cases (MC + grid map) · C5 25° honest |
| #674 | 74328f6a | openmm-bonded       | openmm-core (PR #648)        | 7 cases (bonded · PBC · Ewald) · T6 1e-4 honest · A&S erfc 인라인 |
| #675 | 86060ece | brenda-soap-wire    | brenda-api (PR #635)         | 6 OFFLINE (SOAP + WS-Security MD5) · 순수 hexa MD5 |
| #676 | acc52560 | iedb-mhc-pan        | iedb-epitope (PR #645)       | 6+1 분류 100% (3 alleles, anchor 5.21×) |
| #677 | e4dc986e | rdkit-descriptors   | rdkit-subset (PR #652)       | 7 cases × 5 desc = 35 assert PASS · glucose TPSA 118.22 honest |

- [x] 6 마일스톤 체크박스 STDLIB.md 갱신 (각 deferred sub-sub-feature → cycle 4 후보로 메모)
- [x] 0 fail · 3 honest 측정 deviation 명시 (vina C5 25° · openmm T6 1e-4 · rdkit glucose acyclic)
- [x] 모든 모듈 `hexa parse` clean (cycle-2 와 동일 gate)
- [x] inbox patch 1건 신규 — `codegen-cross-module-struct-constructor-2026-05-25` (vina agent 발견)

진행 상태: **20/21 actionable closed** (95.2%) · 1 deferred (open-babel-subset, GPL-2 라이선스). 6 새 sub-sub-feature 가 cycle 4 후보 (rdkit full 68-type SMARTS · Ertl S/P · SSSR · vina BFGS local opt · iedb ANN weight · brenda credentials manager).

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
