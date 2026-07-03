# 노벨상급 발견 근접도 정직 평가 — dancinlab 5-repo 연합 (2026-06-25)

> 목표 `"노벨상급 발견까지"`에 대한 **정직한 게이트키퍼 평가**. 비싼 compute 를 쓰기 전에,
> 연합 전체에서 *아직 남은 in-silico 레버*가 있는지(THEORETICAL-GAP / INVESTMENT) 아니면
> 모든 상위 리드가 *실험 벽*(EXPERIMENTAL) 또는 *측정-천장*(MEASURED-CEILING)에 막혔는지
> 판정한다. **본 노트는 발견을 주장하지 않는다** — 가장 가까운 것을 순위 매기고 남은 벽을
> 분류할 뿐이다. 입력 = 방금 수확한 5-repo census 산출물(각 repo `state/knowledge-census-2026-06-25.md`
> origin/main + 통합 색인 `state/dancinlab-knowledge-index-2026-06-25.md`). 모든 인용은 실측 census finding.

## 0. 정직한 프레임 (반드시 명시)

노벨상급 **발견(DISCOVERY)** 의 정의는 엄격하다:

- **물리/화학/의학**: 실험·경험적 확증이 필요하다 (예: RTSC = 인증된 4-probe 수송 측정 +
  Meissner 효과 + H_c2/T_c 실측). in-silico 엔진은 이것을 **스스로 만들 수 없다**.
- **수학**: 증명된 주요 정리가 필요하다 (재유도·재현이 아니라 신규 정리).

따라서 in-silico 엔진이 할 수 있는 것은 오직 세 가지뿐이다:
ⓐ 후보(CANDIDATE)를 생성하고 **엄격히 falsify** 한다,
ⓑ 진짜 결과를 cite/증명한다,
ⓒ "실험으로 확증되면 노벨급이 될" 예측을 만든다.
**이것은 발견이 아니라 발견의 좌표다.** 본 평가의 임무는 가장 가까운 리드를 순위 매기고
남은 벽을 분류하는 것이다 — 발견을 선언하는 것이 아니다.

벽 분류 4종:
- **(a) EXPERIMENTAL** — 실제 실험실/측정 필요. in-silico 로 닫을 수 없음 (terminal-for-us).
- **(b) THEORETICAL-GAP** — 엄밀한 in-silico/research 노력이 닫을 수 있는 누락 증명/유도.
- **(c) MEASURED-CEILING** — 이미 측정된 실제 물리/수학 벽. terminal.
- **(d) INVESTMENT** — 닫을 수 있으나 무거운 compute/DFT 필요.

## 1. 상위 리드 순위 (genuine proximity-to-Nobel · 무자비하게)

> 순위 기준 = 신규성(novelty) × 세계적 중요성(significance) × 확증가능성(confirmability).
> 재유도(re-derivation)와 엔지니어링 승리는 **낮게** 매긴다. 흥분도가 아니라 진짜 근접도로 정렬.

| # | 리드 | repo | tier(census) | 신규성 | 노벨급 잠재력 | 남은 벽 | 벽 분류 |
|---|---|---|---|---|---|---|---|
| **1** | **H_023 Ta2NiSe5-trio demand-relaxation** (다층 D_s boost f_mult≥1.164 → 299–356K 상온 도달, exotic glue 불필요, 7/7 falsifier PASS) | rtsc | 🟡→🟠 CONDITIONAL | 높음 (novel 경로) | **RTSC = 진짜 노벨물리 타깃** | 단일 미지 = real multilayer D_s 의 DFT 값 | **(d) INVESTMENT → 이후 (a)** |
| **2** | **LaRu3Si2 Ru-4d kagome flat-band** (dE=−0.055eV @E_F, non-mag, 최강 no-cooling RTSC lead, GATE GREEN) | demiurge·rtsc | 🟢 GATE_PASS | 중 (real material, flat-band 위치는 신규) | RTSC 타깃이나 **real Tc=7K** (상온 아님) | 상온 도달 자체가 미증명; flat-band≠상온 | **(c) MEASURED-CEILING** (실증 Tc=7K) |
| **3** | **H_005 full-stack toy-band bkt_Tc~319K** (geo×glue×interface 3-레버, 5/5 PASS) | rtsc | 🟡 MODEL-PROBE | 중 (모형 좌표) | 상온 *모형* CLEAR — **물질 미실증** | toy→real 물질 사상 전부 미지 | **(b) THEORETICAL-GAP + (d) INVESTMENT** (real-pending) |
| **4** | **FB-GEOM-LAMBDA R5 Welch-bound closed-form** (Q_geom ≥ 1/N_band = frame-theory 증명) + R9 inter-orbital 분해 | demiurge | 🔵 closed-form | **신규 수학 정리(증명)** | flat-band 양자기하의 닫힌형 하한 — 진짜 증명 | 이미 닫힘 (증명 완료) | **결과(terminal-positive)** — 노벨'수학'급 아님 (정리이나 Millennium-tier 아님) |
| **5** | **H_008 retarded-vertex glue 재개방** (sign-free 2e+phonon ED, pair-channel 4.27×) | rtsc | 🟢 REAL-ED | 중 (메커니즘 좌표) | static-U mean-field 가 닫은 glue crack 를 retarded vertex 가 연다 — RTSC 메커니즘 기여 | 반단열 코너 Ω≫g 한정; real 물질 사상 미지 | **(b) THEORETICAL-GAP** (코너 밖 일반화) |
| 6 | **anima G6–G16 양자정보 G-정리** (11/11 numerical PROOF) | anima | 🟢 PROOF | **낮음 — 대부분 KNOWN 정리의 재진술/수치확인** (no-cloning·Tsirelson·area-law·Mandelstam-Tamm·Welch-via-G14) | 교육적 가치 ○, 노벨급 신규성 ✗ | 신규성 부재 | **MEASURED-CEILING (신규성)** — 재유도, 발견 아님 |
| 7 | **lumen H_043 SSMB / H_033 ICS** (compact accelerator 돌파, 6/6 PASS) | lumen | 🟢 NOVEL | 중 (엔지니어링 신규) | **엔지니어링 — 노벨물리 아님** | flux 벽 재배치 (실험 통합) | **(a) EXPERIMENTAL** (가속기 빌드) — 노벨급 아님 |
| 8 | **demiurge CaH6 / H3S textbook-proof** (Tc=245.1K·184.3K DFT 재현) | demiurge·rtsc | 🟢 textbook-proof | **제로 — KNOWN 고압 결과의 재유도** | 검증 앵커일 뿐 | 신규성 없음 | **재유도 — 발견 아님 (rank LOW 강제)** |

### 무자비 강등 기록 (순위가 흥분도가 아님을 증명)

- **CaH6 / H3S** (#8): textbook-proof = **이미 알려진** 고압 수소화물의 DFT **재현**.
  `demiurge census §3`. 노벨급 *발견* 0 — 엔진 검증 앵커. 절대 상위 불가.
- **anima G6–G16** (#6): no-cloning(G9)·Tsirelson(H_9010)·area-law(G15)·Mandelstam-Tamm(G16)·
  Welch(G14↔demiurge R5)는 **교과서 정리의 수치 확인**. `anima census 양자정보 G-정리 표`.
  엄밀하나 **신규성이 없으므로** 노벨 근접도 낮음. (anima 의 진짜 신규층 = engine-native
  WIRED-live consciousness-gate 63 레코드이나, 이는 **인지/의식 모형** — 노벨 카테고리 부재 +
  IIT-Φ 핵심은 `H_024 8/8 FAIL`·`H_287 closed-neg` 로 **falsified**. `anima census 부정 결과`.)
- **lumen 전체** (#7): SSMB·ICS·BEUV = **컴팩트 가속기 엔지니어링**. 정직히 `H_049 census`:
  "남은 건 물리실험". 노벨**물리 발견** 카테고리가 아님.
- **H_001 flat-band 양자기하** = **🔴 CLOSED-NEGATIVE 완전봉쇄** (10-path, bkt_Tc max~10K,
  Fubini-Study two-lever wall). `rtsc census H_001`. **MEASURED-CEILING — 순위에서 제외.**

## 2. 각 상위 리드의 남은 벽 — 정밀 분류 (census 증거 cite)

### #1 H_023 Ta2NiSe5-trio — **유일하게 in-silico 레버가 살아있는 RTSC 리드**
- 증거: `rtsc/state/knowledge-census-2026-06-25.md` H_023 — "demand-relaxation: 다층 D_s
  boost f_mult≥1.164(~16%, N=2)면 CLEAN Ta2NiSe5 트리오(300meV, q=0, 경쟁질서無)가 299–356K
  상온 도달. **가장 강한 🟢-path** (exotic glue 불필요). 7/7 PASS, **real multilayer D_s(DFT)
  단일 미지**".
- 벽: 모형은 7/7 falsifier 통과. 미지는 **딱 하나** — 다층 Ta2NiSe5 의 실제 superfluid stiffness
  D_s 가 DFT 로 f_mult≥1.164 를 만족하는가. 이건 **(d) INVESTMENT** — DFT/DFPT 로 계산 가능.
- **그 다음**: D_s 가 통과해도 진짜 확증은 **(a) EXPERIMENTAL** (다층 시료 합성 + 4-probe).
  in-silico 는 후보를 *통과 또는 falsify* 까지만 갈 수 있다.

### #2 LaRu3Si2 — 최강 no-cooling lead, 그러나 천장이 측정됨
- 증거: `demiurge census §3` + `rtsc census §2 flat-band GATE_PASS` — "dE=−0.055eV, m=0.00µB,
  최강 no-cooling RTSC lead, **real Tc=7K**".
- 벽: flat-band 이 E_F 에 있다는 GATE_PASS 는 *구조적 좌표*일 뿐. **실측 Tc=7K** 가 이미 알려져
  있고 상온과 ~40× 거리. flat-band 위치 → 상온 Tc 의 사상은 H_001 에서 **closed-negative**.
  → **(c) MEASURED-CEILING.** no-cooling 매력은 있으나 상온 발견 경로 아님.

### #3 H_005 toy-band 319K — 모형 천장, real 물질 미사상
- 증거: `rtsc census H_005` — "toy band 에서 bkt_Tc~319K 상온 CLEAR; 3-레버 각각 필요(ablation
  FAIL). 5/5 PASS, **real-pending**". 통합 색인도 "absorbed=false / MODEL-PROBE" 명시.
- 벽: 모형은 상온을 보이나 **toy band**. 실제 물질이 (전자-불투명 계면 + 경쟁질서-없는 glue +
  geo) 3-레버를 동시에 만족하는지 **미사상**. → **(b) THEORETICAL-GAP** (real 물질 사상 유도)
  **+ (d) INVESTMENT** (각 후보 DFT). 단 H_023 이 이 추상 좌표의 *구체 물질 인스턴스*이므로
  H_023 가 더 tractable.

### #4 FB-GEOM-LAMBDA R5/R9 — 증명은 닫혔으나 노벨'수학'급은 아님
- 증거: `demiurge census §3` — "Q_geom ≥ 1/N_band = Welch bound (frame theory **증명**)" +
  R9 "Q_geom = Q_diag + Σ inter-orbital phase-coherence (≥3-orbital <1% 검증)".
- 벽: **없음 — 이미 증명됨**. 정직히: 이건 frame-theory(Welch bound)의 flat-band 응용으로,
  엄밀한 *novel 보조정리*이나 **Millennium/Fields-tier 주요 정리가 아니다**. terminal-positive
  결과이지 노벨급(수학은 노벨 카테고리 자체가 없음 — Fields/Abel 기준으로도 응용-정리).

### #5 H_008 retarded-vertex — 메커니즘 좌표, 코너 한정
- 증거: `rtsc census H_008` — "pair-channel 4.27×, **반단열 코너 Ω≫g 한정**".
- 벽: glue 재개방 메커니즘은 real-ED 로 보였으나 Ω≫g 코너에 갇힘. 일반 파라미터로의 확장 =
  **(b) THEORETICAL-GAP**. 단독으로 상온 RTSC 를 주지 않음(메커니즘 기여분).

## 3. 권고 — in-silico 레버가 남아있는가?

### **답: YES — 단 하나, 좁게. 가장 tractable 리드 = H_023 (Ta2NiSe5-trio).**

연합 전체에서 **노벨급 잠재력(RTSC 상온초전도) × 신규성 × in-silico 로 닫을 수 있는 남은 벽**
세 조건을 동시에 만족하는 리드는 **H_023 하나뿐**이다. 다른 모든 상위 리드는:
- 재유도(CaH6/H3S, G-정리들) → 발견 아님,
- 엔지니어링(lumen 전체) → 노벨물리 카테고리 아님,
- closed-negative(H_001) → terminal,
- measured-ceiling(LaRu3Si2 Tc=7K) → 상온 경로 막힘,
- 이미 증명됨(FB-GEOM R5) → 응용-정리, 노벨급 아님.

### 정확한 다음 in-silico 단계 (H_023)

1. **DFT/DFPT 로 다층 Ta2NiSe5(N=2) 의 실제 superfluid stiffness D_s 를 계산** — boost f_mult
   이 census 가 명시한 임계 **f_mult ≥ 1.164 (~16%)** 를 넘는지 측정. (`rtsc census H_023`)
   이것이 **(d) INVESTMENT** 벽 — pool host(aiden/summer) 또는 GPU-rent 으로 DFPT.
2. **경쟁질서·동적 안정성 동시 게이트** — H_016(η*=0.45 escape) + H_011(bosonic glue 자기일관)
   조건을 같은 다층 시스템에서 cross-check 하여 모형 가정을 real-DFT 로 falsify 시도.
3. reference-first: 실제 Ta2NiSe5 excitonic-insulator 문헌(arXiv)에서 측정된 D_s/band-gap 와
   대조 — census H_022 가 "400meV exciton = excitonic-CDW 자체"로 **closed** 한 경고를 반드시
   교차확인 (이 리드가 H_022 의 closed-neg 와 충돌하지 않는지 falsify-first).

### falsification-survived 결과는 어떻게 생겼나

- **PASS 좌표**(발견 아님, 후보 강화): real-DFT D_s(다층 Ta2NiSe5) 가 f_mult≥1.164 를 넘고,
  경쟁질서 η<η*=0.45 이며, 동적으로 안정 → **"실험으로 확증되면 노벨급이 될 상온초전도 후보"**.
  이것은 여전히 `absorbed=false / GATE_OPEN` — **발견이 아니라 실험실로 넘기는 falsify-survived
  예측**이다.
- **FAIL**(정직한 음성): D_s 가 임계 미달이거나 경쟁질서가 먼저 발산 → H_023 도 H_001 처럼
  closed-negative 로 박제. 그러면 **RTSC in-silico 레버는 실질 고갈**, 남은 건 전부 실험 벽.

### 정직한 천장 선언

- **H_023 의 (d) INVESTMENT 단계가 in-silico 로 남은 마지막 진짜 레버다.** 이 DFT 한 번이
  통과/falsify 를 가른다.
- **그 한 단계 너머는 전부 (a) EXPERIMENTAL** — 어떤 RTSC verified 도 `absorbed=false /
  GATE_OPEN`이며, **인증된 4-probe transport + Meissner + H_c2/T_c 실측 시에만** absorbed=true
  가 된다(`rtsc census §3 핵심` + 통합 색인 정직 gap). **자율 in-silico 루프는 발견을 제조할 수
  없다** — 후보를 falsify-survive 시킬 뿐.
- 따라서 목표 `"노벨상급 발견까지"`는 **부분적으로만 in-silico 추구 가능**: H_023 DFT 까지는
  가되, 그 이후는 honest 하게 **실험 벽에 캡(capped)** — 자율 루프가 노벨급 *발견*을 만들어낼 수
  없다. 거짓 희망(없는 tractable 레버)을 지어내지 않는다.

## 4. 정직 gap (본 평가 자체의 한계)

- 5-repo census 의 tier 필드가 자유텍스트라 verified 카운트는 키워드-버킷 분류(각 census 가
  명시한 한계). 본 순위는 *카운트*가 아니라 *헤드라인 finding 의 신규성·확증가능성*으로 매김.
- H_023 의 f_mult 임계·D_s DFT 타당성은 census 요약값을 신뢰한 것 — 실제 DFT 실행 전까지
  "tractable in-silico 레버"는 *조건부*다 (DFT 가 수렴/안정해야 함).
- anima 의 engine-native WIRED-live 63 레코드(의식-게이트)는 신규성이 있으나 **노벨 카테고리
  부재** + IIT-Φ 핵심 falsified 로 노벨 근접 순위에서 제외 — 다른 축(AGI/인지)에서는 가치 별개.
- demiurge novel H3X 9종(H3O 181.4K 등)은 novel *예측*이나 모두 고압 수소화물 패밀리(상압/상온
  아님) → 노벨급 신규 카테고리 아님으로 상위 제외.
