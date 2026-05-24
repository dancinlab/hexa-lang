# TTR external library port candidates → hexa-native

> opened: 2026-05-24 KST · source: `demiurge/TTR/research/external_libraries.md` (web inventory)
> target: hexa-lang stdlib (per demiurge @D d3 — demiurge=docs SSOT, hexa-lang=code SSOT)
> driver: TTR (Topical Tattoo Removal) domain M3 (in-silico screening) + M5 (MD/QM) 필요 외부 도구 hexa-native 포팅 후보.

## TL;DR

TTR M3-M5 진행 위해 외부 cheminformatics + docking + MD 도구가 필요. 5개 핵심 후보를 hexa-native 로 (부분) 포팅하면 first-principles in-silico 트랙이 hexa-lang 안에서 닫힘. 가장 high-leverage 는 **AutoDock Vina full port** + **RDKit subset (SMILES + descriptors)** + **PubChem/BRENDA REST thin adapter**.

## 후보 우선순위

| # | name | upstream | 라이선스 | 포팅 scope | LOC 추정 | TTR milestone | priority |
|---|---|---|---|---|---|---|---|
| 1 | **AutoDock Vina** | C++ | Apache-2 | full port (작은 codebase) | ~5 kloc | M3 docking | ★★★ |
| 2 | **RDKit subset** | C++/Python | BSD-3 | SMILES parser + basic descriptors + 분자 IO | ~2-3 kloc subset | M3 docking input prep | ★★★ |
| 3 | **OpenMM core** | C++/Python | MIT+LGPL | MD integrator (Verlet) + LJ forcefield | ~3-5 kloc core | M5 MD/QM | ★★ |
| 4 | **Open Babel subset** | C++ | GPL-2 | 분자 format IO만 (MOL/SDF/PDB) | ~1-2 kloc subset | M3 prep | ★ |
| 5 | **PubChem PUG-REST adapter** | thin wrapper | open | hexa-native HTTP client + JSON parser | ~200 lines | M3 batch lookup | ★ (가벼움) |
| 6 | **BRENDA REST adapter** | thin wrapper | open | enzyme metadata lookup | ~200 lines | M3 효소 candidate | ☆ (가벼움) |
| 7 | **UniProt + AlphaFold REST adapter** | thin wrapper | open | protein structure fetch (PDB · JSON) | ~300 lines | M3 docking target | ☆ (가벼움) |

> 라이선스 주의: Open Babel 은 GPL-2 → hexa-lang 라이선스 정합 확인 필요. RDKit BSD-3 · Vina Apache-2 · OpenMM MIT 는 안전.

## ASCII — 포팅 의존성

```
  [Tier-1 thin adapter — 1주 내]
   PubChem ──┐
   BRENDA   ──┤── hexa-native HTTP client + JSON
   UniProt  ──┘   (M3 batch lookup 즉시 사용 가능)
                                  │
                                  ▼
  [Tier-2 cheminformatics — 1-2 개월]
   RDKit subset (SMILES + descriptors)
   Open Babel subset (분자 IO)
                                  │
                                  ▼
  [Tier-3 docking — 2-3 개월]
   AutoDock Vina full port
                                  │
                                  ▼
  [Tier-4 MD — 6+ 개월]
   OpenMM core (Verlet + LJ)
   M5 MD/QM 진입 가능
```

## 정합 / 근거

| @D 룰 | 적용 |
|---|---|
| d1 (completed-form) | in-silico 단계가 wet-lab 전 닫힘. 외부 의존 → hexa-native 흡수로 trace 닫힘 |
| d3 (code in stdlib home) | demiurge=docs / hexa-lang=code 분업 — 본 inbox 노트가 그 분업 트리거 |
| d6 (first-principles) | Vina 의 empirical scoring 은 force-field 기반, OpenMM 의 MD 도 first-principles. ML 의존 X |
| d7 (compute sizing) | Vina 도킹 = laptop CPU OK · OpenMM MD ≥ 20 atoms 시 GPU pod |
| d8 (Vast trouble → inbox) | 본 노트도 inbox 패턴 — Vast 외 다른 외부 의존도 같은 형식 |

## Scope caveats (정직)

- **RDKit full** = 수년 작업. 포팅 = subset 만 (SMILES parser + basic descriptors + 분자 IO).
- **OpenMM full** = 수십 kloc + GPU CUDA kernel. 포팅 = MD core (integrator + simple forcefield) 만.
- **Vina 5 kloc** = 직접 포팅 가능한 규모. scoring function 의 empirical term 일부는 force-field 의존.
- **Adapter 류** = 외부 REST endpoint 의존 → 외부 SLA 영향 받음. PubChem 무료, BRENDA 학술용 무료, UniProt 무료.
- **AlphaFold DB API sunset 2026-06-25** (per demiurge external_libraries.md §8 ⓦ) → 새 endpoint 문서화 후 adapter 작성.

## M3 즉시 사용 path (포팅 전)

만약 포팅 전에 M3 진행 필요시:
1. Python+RDKit/Vina 로 1차 batch screen (demiurge/TTR/scripts/ 에 일회용 Python)
2. 결과를 design doc 으로 흡수 (demiurge/TTR/research/m3_candidates.md)
3. 그 뒤 hexa-native 포팅이 점진적으로 Python 의존 대체

→ wet-lab 전 in-silico 단계가 외부 도구 의존이라도 first-principles 검증 가능 (Vina scoring · OpenMM forcefield). 다만 hexa-native 흡수가 d3 정합 정상 경로.

## 출처

- demiurge: `TTR/research/external_libraries.md` (12 DB · 12 enzyme · 10 in-silico tool · 7 fail history · 12 MN supplier inventory · 2026-05-24)
- TTR @goal: 바르는 타투제거 (분기: TTR-CREAM · TTR-MN)
- 관련 milestone: TTR-CREAM M3 / TTR-MN M3 / 양 track M5

## Status

✅ **ABSORBED** (2026-05-24T21:30Z) — STDLIB 도메인 `### TTR — in-silico track` 섹션으로 흡수. 6 마일스톤 신규 등록 (open-babel 1개는 GPL-2 라이선스 검토 DEFERRED). 후속 진행 = STDLIB.md milestone 체크박스 + STDLIB.log.md 사이클 기록.
