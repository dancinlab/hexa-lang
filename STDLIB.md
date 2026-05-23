# STDLIB — current state

@goal: 외부 라이브러리·API·알고리즘을 hexa-native stdlib으로 포팅 — HERPES · TTR · 기타 도메인이 의존하는 외부 도구 모두 `stdlib/` 안 self-contained 모듈로 흡수, Python/외부 CLI shell-out 제거. 각 모듈 `_test.hexa` measured-oracle PASS 까지 absorbed=false (per d5).

scope:
- in-scope: 외부 API 클라이언트 · 표준 알고리즘 · 데이터베이스 fetch · 수치 solver
- out-of-scope: 도메인-특화 implementation (그건 도메인 stdlib 안에서) · UI · 운영 인프라

ref:
- existing stdlib 카탈로그: `hexa stdlib` (PR #630 부터 헤더 자동 추출, STDLIB.json 폐기)
- demiurge sibling 사용처: `/Users/ghost/core/demiurge/HERPES/M1-M9` · `/Users/ghost/core/demiurge/TTR/research`

## milestones

- [x] arxiv-api stdlib — arXiv API 클라이언트 (search · fetch by id · abstract · pdf-link) → `stdlib/research/arxiv.hexa`
- [ ] pubmed-api stdlib — NCBI E-utilities PubMed wrapper (esearch · efetch · elink) → `stdlib/research/pubmed.hexa`
- [ ] clinicaltrials-api stdlib — clinicaltrials.gov v2 REST 클라이언트 (NCT id lookup · status · arms) → `stdlib/research/clinicaltrials.hexa`
- [ ] ncbi-entrez stdlib — NCBI E-utilities 통합 (GenBank · RefSeq · GEO · SRA · Gene · Taxonomy) → `stdlib/bio/entrez.hexa`
- [ ] seq-align stdlib — pairwise (Needleman-Wunsch · Smith-Waterman) + MSA (MAFFT-style progressive) first-principles 구현 → `stdlib/bio/seq_align/`
- [ ] crispr-off-target stdlib — Cas-OFFinder-style genome-wide off-target search · mismatch tolerance · PAM constraint → `stdlib/bio/crispr_gene_editing/off_target.hexa`
- [ ] doench-grna-score stdlib — Azimuth-style on-target gRNA scoring (Doench 2016 closed-form features) → `stdlib/bio/crispr_gene_editing/grna_score.hexa`
- [ ] iedb-epitope stdlib — IEDB lookup + HLA binding prediction (NetMHCpan-style PSSM/SVM 코어) → `stdlib/bio/immuno/epitope.hexa`
- [ ] mirna-target stdlib — miRBase mature-miRNA registry + TargetScan seed-match scoring → `stdlib/bio/mirna/target.hexa`
- [ ] ode-bifurcation stdlib — Runge-Kutta (RK4 · RK45 adaptive) + stiff (BDF) ODE solver + saddle-node bifurcation 탐지 → `stdlib/math/ode.hexa`

### TTR — in-silico track (M3 docking · M5 MD/QM, source: `inbox/notes/2026-05-24-ttr-external-port-candidates.md`)

Tier-1 — thin REST adapter (★ priority, ~200-300 LOC each, TTR M3 즉시 사용):

- [ ] pubchem-api stdlib — PubChem PUG-REST 클라이언트 (compound CID lookup · SMILES · properties · batch fetch) → `stdlib/chem/pubchem.hexa`
- [ ] brenda-api stdlib — BRENDA enzyme DB REST 클라이언트 (EC number · KM · kcat · substrate) → `stdlib/bio/brenda.hexa`
- [ ] uniprot-alphafold-api stdlib — UniProt + AlphaFold DB REST 클라이언트 (protein metadata · structure PDB fetch) → `stdlib/bio/uniprot.hexa` ※ AlphaFold DB API sunset 2026-06-25 → 새 endpoint 모니터

Tier-2 — cheminformatics subset (★★★ priority, ~2-3 kloc subset, TTR M3 docking input prep):

- [ ] rdkit-subset stdlib — RDKit-style SMILES parser + basic descriptors (MW · logP · HBA/HBD · TPSA) + mol IO → `stdlib/chem/rdkit_subset/`
- [ ] open-babel-subset stdlib — DEFERRED (GPL-2 라이선스 검토 필요) — 분자 format IO (MOL · SDF · PDB) → `stdlib/chem/babel_subset/`

Tier-3 — docking (★★★ priority, ~5 kloc full port, TTR M3 docking):

- [ ] autodock-vina-port stdlib — AutoDock Vina C++ full port (scoring function + Monte Carlo search + grid map) → `stdlib/chem/vina/`

Tier-4 — molecular dynamics (★★ priority, ~3-5 kloc core, TTR M5 MD/QM):

- [ ] openmm-core stdlib — OpenMM MD core (Verlet integrator + Lennard-Jones forcefield + periodic boundary) → `stdlib/chem/md/`
