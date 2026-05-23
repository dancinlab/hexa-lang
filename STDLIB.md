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
