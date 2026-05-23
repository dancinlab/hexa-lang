# NOREFLOW external libraries inventory — DB · 표적 · 도구 · 공급처 catalogue

> **opened:** 2026-05-24 KST · **driver:** demiurge `NOREFLOW` 도메인 (PCI no-reflow / IRI 보호 약물 후보)
> **pattern source:** `inbox/notes/2026-05-24-ttr-external-port-candidates.md` (TTR external library inventory)
> **scope:** 임상시험 · 약물 · 단백질 · imaging endpoint · in-silico · wet-lab · 한국 capacity · 공급처 · fail-history
> **status:** proposed · filing-only (즉시 hexa-native 포팅 트리거 아님, 후속 in-silico track 의 참조 표면)

## TL;DR

demiurge `NOREFLOW` 도메인 (관상동맥 PCI 후 no-reflow / 미세혈관 폐쇄 · ischemia-reperfusion injury 보호 약물 후보 발굴) 작업 시 외부 자원 참조의 표준 catalogue 가 필요. TTR 도메인의 `external libraries inventory` patch 패턴을 NOREFLOW 에 적용해, 70 entry × 10 카테고리로 정리. cardiovascular 특화 항목 (CMR endpoint · IMR · IRI 동물 모델 · 한국 인터벤션 capacity) 포함.

비록 본 patch 는 inventory 등록 (참조 표면 SSOT) 이지만, 후속 in-silico track (mPTP CypD 도킹 · F-ATPase MD · PBPK arm-to-heart) 에서 hexa-native 포팅 후보가 산출될 예정.

## §1 motivation

- demiurge `@D d3` (code = hexa-lang, docs = demiurge): NOREFLOW 의 외부 의존 inventory 는 demiurge 의 design doc 에 머무는 게 자연스러우나, **stdlib 포팅 후보 식별 + adapter 설계 단서** 가 hexa-lang inbox 로 흡수되는 게 정상 경로 (TTR pattern 과 동일).
- cardiovascular 특화 카테고리 (CMR · IMR · IRI 동물모델 · 한국 인터벤션 capacity) 는 TTR (피부과/dermatology) inventory 와 명백히 분리.
- 한국 capacity 우위 표면 (KCT · KAMIR-NIH · 서울대/세브란스 IMR · 일동제약 nicorandil) 명시 → wet-lab 진입 시 partner selection 가속.
- `@D d1` (completed-form): in-silico 단계가 wet-lab 전 닫히려면 외부 DB/도구 매핑이 결정적. inventory 가 그 매핑의 출발선.

## §2 임상시험 / outcome DB

| DB | URL · identifier | 한국 capacity | NOREFLOW 활용 |
|---|---|---|---|
| ClinicalTrials.gov | https://clinicaltrials.gov | OK (참조) | CIRCUS · AMISTAD · INFUSE-AMI 추적 |
| CTRI (인도) | http://ctri.nic.in | — | 동아시아 trial 참조 |
| KCT (한국임상정보) | https://cris.nih.go.kr | 한국 우위 | 한국 trial 등록 + 검색 |
| WHO ICTRP | https://trialsearch.who.int | OK (참조) | 메타-레지스트리 cross-search |
| EU CTR / EudraCT | https://www.clinicaltrialsregister.eu | — | 유럽 trial (CIRCUS 등) |
| jRCT (일본) | https://jrct.niph.go.jp | — | J-WIND · J-MINUET 추적 |
| KAMIR-NIH | https://www.kamir.or.kr | 한국 우위 | 국내 STEMI registry (대규모 cohort) |
| K-ACTION | (국내 인터벤션 등록) | 한국 우위 | IMR sub-study · 미세혈관 분석 |
| HOST 시리즈 (서울대) | — | 한국 우위 | DAPT + ISR + no-reflow 신호 |
| TRIUMPH (Univ. of Michigan) | https://www.umich.edu | — | AMI cohort 비교군 |
| TIMI Study Group | https://timi.org | — | TFC / TIMI flow grade 표준 출처 |
| BiomarCaRE / FinHealth | — | — | 유럽 cardiovascular cohort |

→ **활용 시나리오:** CIRCUS / CYCLE 후속의 mPTP-targeted candidate 신호를 metaregistry × 국내 registry 매칭 시 사용. KAMIR-NIH 와 K-ACTION 은 한국 우위 — 국내 partner 진입의 first-stop.

## §3 약물 / 화합물 DB

| DB | scope | NOREFLOW 활용 |
|---|---|---|
| DrugBank | 약물 전체 + target | adenosine · nicorandil · CsA · NIM811 target 검색 |
| ChEMBL | bioactive molecule | mPTP/CypD 저해제 IC50 · QSAR 입력 |
| BindingDB | binding affinity | CypD-CsA Kd · F0 c-ring binding |
| PubChem | small molecule | 화합물 SMILES + 2D/3D 구조 |
| ZINC22 | virtual screening | preclinical mPTP virtual screen pool |
| RxNorm | 의약품 표준 | 한국 보험/EMR 매핑 (NDC ↔ KFDA) |
| KEGG DRUG | pathway 약물 | 미세혈관 약물 pathway map |
| Reaxys / SciFinder | 합성 경로 (상용) | NIM811 · sanglifehrin 합성 route |
| Open Targets | drug-target evidence | YAP · HIF · ROCK (ISR 도메인과 share) |
| DGIdb | drug-gene interaction | CYP2C19/3A4 → CsA · NIM811 대사 |
| SureChEMBL | patent chem | mPTP-targeted patent landscape |
| ChEMBL Beaker | RDKit-as-a-service | SMILES → descriptor batch |

→ **포팅 후보 (hexa-native):** PubChem PUG-REST + ChEMBL REST adapter (TTR 의 `PubChem PUG-REST adapter` ~200 lines pattern 재사용). DrugBank 는 라이선스 (academic free) 주의.

## §4 단백질 / 표적 DB

| DB | scope | NOREFLOW 활용 |
|---|---|---|
| UniProt | protein metadata | CypD (PPIF, Q08752) · F0F1 ATPase · ANT (SLC25A4) · VDAC (VDAC1-3) |
| PDB | 3D experimental structure | mPTP 구조 가설 · CypD-CsA complex (PDB 2BIT 등) |
| AlphaFold DB | predicted structure | F-ATPase c-ring · ANT predicted (실험구조 부족 시) |
| InterPro | domain family | mitochondrial transit signal · cyclophilin domain |
| STRING | PPI network | mPTP regulator network (CypD · ANT · OSCP · ATP5B) |
| BioGRID | curated interaction | CypD interactome (실험적 evidence weight 比교) |
| Reactome | pathway | IRI · mitochondrial signaling · mPTP opening |
| OMIM | genetic disease | CypD/ANT 변이 phenotype (mitochondrial myopathy) |
| dbSNP | population variant | ALDH2 ethnicity variant (한국인 빈도) |
| ClinVar | clinical variant | 한국 cardiomyopathy variant DB 매핑 |

→ **활용 시나리오:** UniProt + AlphaFold REST adapter (TTR pattern ~300 lines) → mPTP docking target prep 자동화. **AlphaFold DB API sunset 2026-06-25 caveat** 동일하게 적용 (TTR 노트 §caveat 참고).

## §5 imaging / endpoint 표준

| 표준 | scope | NOREFLOW 활용 |
|---|---|---|
| DICOM | imaging exchange | CMR · IVUS · OCT 데이터 표준 |
| HL7 FHIR | EMR exchange | KAMIR-NIH · K-ACTION 데이터 연동 |
| LOINC | lab/imaging code | troponin (LOINC 6598-7) · CK-MB (13969-1) |
| TIMI Frame Count | calc framework | cTFC (corrected TIMI Frame Count) 표준 |
| IMR consensus | calc framework | Pd × Tmn (Fearon 2003 + 후속 consensus) |
| CMR-CRC (Core Lab) | CMR core lab | LGE (delayed enhancement) · MVO 표준 |
| ARC-2 | clinical event adjudication | endpoint adjudication 표준 (academic research consortium 2) |
| Society for CMR (SCMR) | scan protocol | guideline scan protocol (T1/T2 mapping · MVO) |

→ **활용:** endpoint primary 후보 = MVO (microvascular obstruction, LGE 기준) · IS (infarct size, %LV) · IMR < 25-32 cutoff. NOREFLOW design doc 의 endpoint table 정합 검증 출처.

## §6 in-silico / 분석 도구

| 도구 | scope | 라이선스 | NOREFLOW 활용 |
|---|---|---|---|
| NONMEM | population PK | 상용 | M4 (compartmental PK) — STEMI cohort PK |
| PKSim / MoBi (Open Systems Pharmacology) | PBPK | open (academic) | IV vs IC arm-to-heart PK 비교 |
| AutoDock Vina | docking | Apache-2 | mPTP CypD · F-ATPase c-ring docking |
| GROMACS | MD | LGPL | CypD-CsA dynamics (positive control) |
| PyMOL · ChimeraX | structure viz | mixed (academic free) | 구조 검토 / figure |
| Schrödinger (Maestro) | full suite | 상용 | drug design (산업 표준, 라이선스 비쌈) |
| MOE | docking + ADMET | 상용 | preclinical ADMET |
| R / lme4 / survival | stats | GPL | Cox · mixed-effect model |
| Python lifelines · scikit-survival | survival | BSD/MIT | endpoint × HR 분석 |
| MATLAB / SimBiology | systems biology | 상용 | IRI dynamics ODE |
| OpenSAFELY | EHR analytics | open | population-scale evidence (UK pattern) |
| RxRx · DeepChem | ML drug screen | MIT/BSD | repurposing screen (@D d6 — 1st-principles 우선 caveat) |

→ **포팅 후보 (hexa-native):**
- **AutoDock Vina full port** (TTR M3 와 공유) — NOREFLOW 의 mPTP/F-ATPase 도킹에 즉시 활용.
- **GROMACS subset (Verlet + LJ)** — TTR M5 의 OpenMM core port 와 공유 가능.
- **survival 분석 (Cox · KM)** — hexa-native stats stdlib 후보 (BindingDB Kd × clinical HR 연결 시 필요).
- **PBPK ODE solver** — `stdlib/chem/md` (이미 Velocity-Verlet + LJ landed, PR #648) 기반으로 compartmental ODE 확장 가능.

## §7 wet-lab / 동물 모델 protocol

| protocol | scope | 한국 capacity | 비고 |
|---|---|---|---|
| Langendorff isolated heart | ex vivo IRI | 서울대 · 연세대 capacity | rat / rabbit / guinea pig |
| LAD ligation (mouse/rat/pig) | in vivo MI 모델 | 서울대 의대 · 가천대 | rat = 표준 |
| Sprague-Dawley LAD I/R | rat IRI 표준 | 한국 다수 | reproducibility 높음 |
| rabbit ischemic preconditioning | classic IRI | 부산대 | 1980s 표준 모델 |
| pig MI + reperfusion | large animal | 아산생명과학연구원 | clinical scale-up 게이트 |
| isolated cardiomyocyte (Ca²⁺ imaging) | in vitro IRI | 서울대 의과학 | mitochondrial Ca²⁺ overload 측정 |
| mitochondrial isolation + swelling assay | mPTP 직접 측정 | 서울대 · KAIST | mPTP opening = OD540 감소 |
| siRNA / CRISPR CypD knockdown | mPTP gene-level | 한국 가능 (다수 기관) | positive control validation |
| Akita / streptozotocin DM rat | comorbidity 모델 | 한국 capacity | 당뇨 + IRI (cohort 정합) |

→ **활용 시나리오:** in-silico M3-M5 통과 후보가 wet-lab 진입 시, **rat LAD I/R (1차) → rabbit (2차) → pig (large animal, regulatory enabler)** 라데가 한국 capacity 내에서 닫힘.

## §8 한국 capacity DB

| 기관 | capacity | 위치 | 비고 |
|---|---|---|---|
| 서울대학교병원 | IMR · CMR · 동물 IRI · 임상시험 | 서울 | 종합 capacity 1st |
| 세브란스병원 (연세대) | IMR · CMR · 인터벤션 | 서울 | 인터벤션 strength |
| 삼성서울병원 | IMR · CMR · multinational trial 운영 | 서울 | trial 운영 우위 |
| 아산병원 | CMR · 대규모 cohort | 서울 | retrospective cohort 우위 |
| 분당서울대병원 | IMR · 인터벤션 | 분당 | 도시-외곽 hybrid cohort |
| 고려대안암병원 | 인터벤션 | 서울 | DAPT 연구 |
| 한양대병원 | 인터벤션 | 서울 | — |
| 부산대학교병원 | 인터벤션 + 동물 모델 | 부산 | 영남권 cohort |
| 아산생명과학연구원 | pig large-animal IRI | 서울 | regulatory scale-up |
| 카이스트 의과학대학원 | 분자/세포 IRI · mitochondrial bio | 대전 | basic science 우위 |

→ **partner-selection 가속:** in-silico 통과 후 **서울대/세브란스/삼성** = clinical trial 운영, **카이스트/아산생명과학** = wet-lab mechanism-of-action. 두 트랙 병행 가능.

## §9 supplier (약물 · reagent · 디바이스)

| 공급처 | 카테고리 | 한국 가용 | 비고 |
|---|---|---|---|
| Sigma-Aldrich (Merck) | reagent · 분석급 CsA · 분석급 adenosine | OK (정상 ETA) | 표준 |
| Cayman Chemical | drug research-grade (NIM811 · TRO40303 등) | OK (수입) | research-grade 우위 |
| Tocris (Bio-Techne) | pharmacology tool compound | OK (수입) | mPTP modulator 다수 |
| MedChemExpress (MCE) | clinical-grade analog | OK (수입) | 가격 우위 |
| Abbott (PressureWire X / Pressure Tip) | IMR pressure-wire | OK (인터벤션실 표준) | IMR 측정 device |
| Boston Scientific (aspiration · DPD) | 흡인 catheter · distal protection | OK | TASTE/TOTAL 후 routine 권고 down |
| Terumo (microcatheter Finecross · Caravel) | microcatheter | OK · 일본우위 | IC 약물 전달 |
| 일동제약 / 종근당 | nicorandil 국내 공급 | 한국 우위 | 일본 NICORE 추적, 국내 적응증 확장 가능 |
| 한미약품 | 신약 개발 partner | 한국 | drug-discovery partner 후보 |
| Boryung Pharm (보령) | cardiovascular 국내 marketer | 한국 | 카나브 (ARB) — 미세혈관 약물 partner 후보 |

→ **공급망 caveat:** Cayman/Tocris/MCE 는 수입 (1-3주 ETA · KFDA non-clinical OK). Abbott IMR pressure-wire 는 인터벤션실 보유 여부 사전 확인 필요.

## §10 fail history (NOREFLOW 도메인 임상 실패 학습)

| trial | 약물 / 개입 | year | 결과 | 교훈 |
|---|---|---|---|---|
| CIRCUS | CsA STEMI IV bolus | 2015 | neutral primary | calcineurin off-target (immunosuppression) + dose ceiling. CsA 자체 한계, **NIM811/sanglifehrin (non-immunosuppressive)** 로의 pivot 필요 |
| CYCLE | CsA STEMI | 2016 | neutral 확증 | CIRCUS replicate → CsA 단독 IV 경로 dead. mPTP target 자체 wrong 아님 (CypD KO mouse evidence 강함), **delivery/dose 문제** |
| EMBRACE | MTP-131 (elamipretide) STEMI | 2016 | neutral | IV PK 부족 (myocardium에 도달 부족) → arm-to-heart PK 사전 검증 mandate |
| MITOCARE | TRO40303 | 2015 | neutral + GI 부작용 | dose-limiting toxicity → off-target screening + 안전역 사전 정의 필요 |
| AMISTAD-II | adenosine IV high-dose | 2005 | 전체 cohort neutral, anterior MI subset positive | enrichment design — anterior MI subgroup 으로 next-trial 설계 |
| TASTE | thrombectomy routine | 2013 | clinical event 차이 없음 | routine 흡인 → 선택적으로 down |
| TOTAL | thrombectomy routine | 2015 | stroke 신호 ↑ | TASTE 확증 + safety signal → routine 권고 완전 down (2017 guideline) |
| INFUSE-AMI | IC abciximab primary | 2012 | neutral primary, BMS subset positive | IC vs IV 경로 effect size 차이 있지만 routine 권고 안됨. **DES era 에서 효과 희석** |
| ON-TIME 2 | tirofiban pre-hospital | 2008 | TIMI flow 개선 但 long-term endpoint 부족 | surrogate (TIMI flow) ≠ clinical endpoint, hard endpoint 진입 게이트 |
| J-WIND-ANP | atrial natriuretic peptide | 2007 | 일본 cohort positive, 서구 미확증 | regional reproducibility caveat — multinational design 필요 |

→ **fail-history 흡수 = NOREFLOW 도메인 design rule:**
- **F1.** mPTP target 자체는 wrong 아님 (CypD KO 강한 evidence) — CsA 의 **immunosuppression off-target + IV PK 한계** 가 신호 dilute.
- **F2.** IV → IC (intracoronary) 또는 selective microcatheter delivery 가 effect size 회복 후보.
- **F3.** enrichment design (anterior MI · IMR > cutoff) = primary endpoint 도달 확률 ↑.
- **F4.** surrogate (TIMI flow · IMR) → hard endpoint (MACE · HF hospitalization · CV death) 진입 게이트 필수.
- **F5.** multinational/multiregional design — single-region positive (J-WIND-ANP) 의 일반화 실패 학습.

## §11 metadata

```
status:     proposed
type:       inventory-registration
priority:   P2 (NOREFLOW 작업 가속, blocking 아님)
size:       ~70 entries × 10 categories
reviewer:   TBD
related:    demiurge/NOREFLOW (도메인 직접 driver)
            demiurge/TTR    (pattern source — inbox/notes/2026-05-24-ttr-external-port-candidates.md)
references: §2 ClinicalTrials.gov + KCT · KAMIR-NIH (한국 우위)
            §3 DrugBank · ChEMBL · PubChem (포팅 후보)
            §4 UniProt · PDB · AlphaFold DB (mPTP target prep)
            §5 IMR consensus (Fearon 2003) · ARC-2 (endpoint adjudication)
            §6 AutoDock Vina · GROMACS subset (포팅 우선)
            §7 LAD I/R rat (1차) → rabbit (2차) → pig (large animal)
            §8 서울대/세브란스/삼성 (clinical) + 카이스트/아산생명과학 (wet-lab)
            §9 Cayman/Tocris/MCE (수입) · 일동제약/종근당 (nicorandil 국내)
            §10 CIRCUS · CYCLE · EMBRACE · MITOCARE · AMISTAD-II · TASTE/TOTAL · INFUSE-AMI · J-WIND-ANP
```

## §12 정합 / 근거

| @D 룰 | 적용 |
|---|---|
| d1 (completed-form) | NOREFLOW 의 in-silico 단계 (M3 in-silico screening · M4 PBPK · M5 MD) 가 wet-lab 전 닫히려면 외부 DB/도구 매핑이 결정적. inventory 가 그 매핑의 출발선 |
| d3 (code in stdlib home) | demiurge=docs / hexa-lang=code 분업 — 본 patch 가 그 분업의 NOREFLOW 진입 트리거. 포팅 후보 (Vina · GROMACS subset · survival stats · PBPK ODE) 식별 |
| d6 (first-principles) | §6 의 AutoDock Vina (force-field 기반) · GROMACS (MD first-principles) 우선 — ML 도구 (RxRx · DeepChem) 는 보조. mPTP target 의 KO mouse evidence (first-principles biology) 가 도메인의 1st-principle 기반 |
| d8 (Vast trouble → inbox) | 본 patch 형식 자체가 inbox 패턴 — 외부 의존 발견 → hexa-lang inbox 흡수 정상 경로 |

## §13 scope caveats (정직)

- 본 patch 는 **inventory 등록 (참조 표면)** 이고, 즉시 hexa-native 포팅 트리거 아님. 포팅 후보는 §6 의 4개 (Vina · GROMACS subset · survival stats · PBPK ODE) — 후속 별도 patch 로 진행.
- **AlphaFold DB API sunset 2026-06-25** (TTR 노트 §caveat 와 동일) → §4 의 AlphaFold adapter 는 새 endpoint 문서화 후 작성.
- **DrugBank · NONMEM · Schrödinger · MOE** = 상용/라이선스 ($) → academic 시점 검증 우선, 산업 진입 시 commercial 라이선스 필요.
- **한국 capacity (§8)** 는 보고된 기관 capacity 의 신호 수준 — 실제 partner 진입 시 case-by-case 확인 필요.
- **fail history (§10)** 는 negative trial 의 학습 패턴 추출 — 동일 약물의 다른 design (enrichment · IC delivery · non-immunosuppressive analog) 으로 재진입 여지 있음 (CIRCUS → NIM811 / sanglifehrin pivot 가능).
- **§9 IMR pressure-wire (Abbott PressureWire X)** = 한국 인터벤션실 보유율 비교적 높지만 일부 기관 미보유 → trial site selection 시 사전 확인.

## §14 다음 단계 (후속 patch 후보)

1. **mPTP CypD docking adapter** (hexa-native · §6 Vina port + §4 UniProt/PDB adapter) — TTR M3 의 Vina port (~5 kloc) 와 코드 공유.
2. **survival 분석 stdlib (`stdlib/stats/survival`)** — Cox + KM hexa-native (TTR 와 공유 가능, NOREFLOW endpoint table 의 HR 분석에 필수).
3. **PBPK arm-to-heart ODE** — `stdlib/chem/md` (PR #648 landed Verlet + LJ) 위에 compartmental ODE 확장 — IV vs IC delivery 의 myocardium 도달 PK 비교.
4. **KAMIR-NIH / KCT REST adapter** (~200 lines pattern, TTR PubChem adapter 재사용) — 한국 cohort 검색 자동화.
5. **fail-history 학습 rule engine** — §10 의 5개 learning rule (F1-F5) 를 hexa-lang `@D`-style 룰로 등록 (NOREFLOW design 단계의 self-check).

→ **filing-only:** 본 patch 는 inventory + 후속 trigger 의 SSOT 만 등록. 위 5개 후속 patch 는 NOREFLOW 도메인 진행에 맞춰 별도 issue/patch 로 분리.

## 출처

- demiurge: `NOREFLOW/` 도메인 (in-progress, 본 patch 와 sister)
- demiurge: `TTR/research/external_libraries.md` (pattern source — 12 DB · 12 enzyme · 10 in-silico · 7 fail history · 12 supplier inventory · 2026-05-24)
- hexa-lang: `inbox/notes/2026-05-24-ttr-external-port-candidates.md` (포팅 후보 식별의 TTR 선행 사례)
- 표준: TIMI Frame Count (TIMI Study Group · 1996 후속) · IMR (Fearon 2003) · CMR MVO (SCMR consensus) · ARC-2 (academic research consortium 2)
- 한국 cohort: KAMIR-NIH (Korean Acute Myocardial Infarction Registry, NIH-supported phase)
