# STDLIB — log

Append-only history sister of `STDLIB.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

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
