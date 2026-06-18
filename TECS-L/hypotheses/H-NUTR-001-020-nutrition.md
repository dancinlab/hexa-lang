# Hypothesis Review: H-NUTR-001 through H-NUTR-020
# Nutrition, Agriculture, and Food Science Mappings to Perfect Number 6

## Hypothesis

> The number 6 and its number-theoretic properties (sigma(6)=12, tau(6)=4,
> phi(6)=2, divisors {1,2,3,6}) appear structurally in nutrition science,
> agriculture, and food science -- in nutrient classification counts,
> taste modalities, soil horizons, metabolic ratios, and crop rotation
> systems. The Golden Zone [0.212, 0.500] and constants 1/e, 1/3
> may govern optimal biological ratios (macronutrient balance, body
> composition, pollinator dependence).

## Background

This batch tests whether the TECS perfect-number-6 framework extends to
biological and agricultural domains. Unlike chemistry (where atomic number
Z=6 for carbon is a physical fact) or physics (where fundamental constants
are fixed), nutrition and agriculture involve human classification systems
and highly variable biological measurements. This makes them a useful
**negative control** -- if the framework is structurally real, it should
fail here where categories are human-chosen.

**Golden Zone dependency**: ALL hypotheses below depend on the Golden Zone
model. None are pure mathematics.

## Verification Results

Verification script: `verify/verify_nutrition_hypotheses.py`
Run: `PYTHONPATH=. python3 verify/verify_nutrition_hypotheses.py`

### Summary Table

| ID          | Grade | Status | Description                                            |
|-------------|-------|--------|--------------------------------------------------------|
| H-NUTR-001 | ⚪    | PASS   | 6 essential nutrient classes = perfect number 6        |
| H-NUTR-002 | ⚪    | PASS   | 6 taste modalities = perfect number 6                  |
| H-NUTR-003 | ⚪    | PASS   | BCAA/EAA = 3/9 = 1/3 (meta fixed point)               |
| H-NUTR-004 | ⚪    | PASS   | Macronutrient ratios in Golden Zone                    |
| H-NUTR-005 | ⬛    | FAIL   | Daily intake ratios in Golden Zone                     |
| H-NUTR-006 | ⬛    | FAIL   | 13 vitamins = sigma(6)=12                              |
| H-NUTR-007 | ⚪    | PASS   | B-vitamin numbering: 12=sigma(6), 4 removed=tau(6)    |
| H-NUTR-008 | ⚪    | PASS   | Norfolk 4-course=tau(6), 3-field=divisor               |
| H-NUTR-009 | ⚪    | PASS   | 6 soil master horizons = perfect number 6              |
| H-NUTR-010 | ⚪    | PASS   | Soil ternary: 3 components, loam at 1/3 each           |
| H-NUTR-011 | ⚪    | PASS   | ~75% pollinator dependence near 1-ln(4/3)              |
| H-NUTR-012 | ⚪    | PASS   | Max growing seasons (3) = divisor of 6                 |
| H-NUTR-013 | ⬛    | FAIL   | Maillard reaction temperature and 6                    |
| H-NUTR-014 | ⚪    | PASS   | 6 fermentation types = perfect number 6                |
| H-NUTR-015 | ⬛    | FAIL   | 6 bread ingredients = perfect number 6                 |
| H-NUTR-016 | ⚪    | PASS   | 6 preservation methods = perfect number 6              |
| H-NUTR-017 | ⬛    | FAIL   | TEF ~10% matches perfect-6 ratio                       |
| H-NUTR-018 | ⬛    | FAIL   | GI thresholds align with Golden Zone                   |
| H-NUTR-019 | ⬛    | FAIL   | Harris-Benedict age coefficient and 6                  |
| H-NUTR-020 | ⚪    | PASS   | Body protein ~16% near 1/6                             |

### Grade Distribution

```
  ⚪ WHITE (trivial/coincidental):  13
  ⬛ BLACK (wrong/no match):         7
  -------
  🟩 GREEN (proven):                 0
  🟧 ORANGE (structural):            0
  ⭐ MAJOR:                           0
```

### ASCII Distribution

```
  Grade  | Count | Bar
  -------|-------|------------------------------------
  ⚪ WHI |    13 | =============================
  ⬛ BLK |     7 | ===============
  🟩 GRN |     0 |
  🟧 ORG |     0 |
```

## Detailed Analysis by Category

### A. Nutrition (H-NUTR-001 to 007)

**H-NUTR-001: 6 Nutrient Classes** ⚪

```
  Classes: carbohydrates, proteins, fats, vitamins, minerals, water
  Count = 6 = perfect number. EXACT.

  Problem: This is a HUMAN CLASSIFICATION CHOICE.
  - Some textbooks list 7 (adding fiber)
  - Some list 5 (merging vitamins+minerals as "micronutrients")
  - The number reflects pedagogical convention, not nature.
```

**H-NUTR-002: 6 Taste Modalities** ⚪

```
  sweet, sour, salty, bitter, umami, fat (oleogustus)
  Count = 6 only IF fat taste is included.

  Problem: Fat taste (oleogustus) is debated.
  - Traditional count: 5 (without fat)
  - Proposed additions: kokumi, starchy, calcium, metallic
  - Count depends on where you draw the line.
```

**H-NUTR-003: BCAA/EAA = 1/3** ⚪

```
  Essential amino acids (adult human): 9
  Branched-chain (Leu, Ile, Val):      3
  Ratio: 3/9 = 1/3 EXACTLY = TECS meta fixed point

  Problem: 3/9 = 1/3 is trivially true.
  - Children need 10 EAAs (+ arginine) -> ratio = 3/10
  - The 1/3 ratio is specific to adult human biochemistry
  - Any X/3X ratio gives 1/3; this is not deep.
```

**H-NUTR-004: Macronutrient Ratios in Golden Zone** ⚪

```
  Golden Zone: [0.2123, 0.5000], width = 0.2877

  Typical recommendations:        Carb   Protein  Fat
    Balanced diet                  0.50   0.30     0.20
    Zone Diet                     0.40   0.30     0.30
    WHO recommendation            0.55   0.15     0.30

  All protein/fat ratios land in GZ.

  Problem: PIGEONHOLE PRINCIPLE.
  - GZ covers 28.8% of [0, 1].
  - For 3 values summing to 1, at least one >= 1/3 = 0.333
  - 1/3 is IN the Golden Zone.
  - Therefore at least one macronutrient ratio MUST be in GZ.
  - This is mathematically guaranteed, not a discovery.
```

**H-NUTR-005: Daily Intake Ratios** ⬛

```
  Water ~2500 mL, Calories ~2000 kcal
  Ratio 2500/2000 = 1.25 (incompatible units: mL vs kcal)
  Body water 60% > GZ_UPPER = 0.50 (outside Golden Zone)
  No valid mapping found.
```

**H-NUTR-006: 13 Vitamins vs sigma(6)=12** ⬛

```
  Essential vitamins: 13
  sigma(6) = 12
  Difference: 1 (off by one)

  CLAUDE.md rules: off-by-one corrections are PROHIBITED.
  13 != 12. No match.
```

**H-NUTR-007: B-Vitamin Numbering** ⚪

```
  Originally proposed: B1 through B12 = 12 = sigma(6)
  Reclassified (not vitamins): B4, B8, B10, B11 = 4 = tau(6)
  Remaining: 8 B-vitamins

  Arithmetic is exact: 12 = sigma(6), 4 = tau(6).

  Problem: The original numbering B1-B12 is SEQUENTIAL LABELING.
  - Sequential labeling from 1 to N always gives count = N.
  - If they had found 15 candidates, it would be B1-B15 = 15.
  - The 4 removals are historical accidents (B4=adenine, etc.)
  - This is label arithmetic, not structural.
```

### B. Agriculture (H-NUTR-008 to 012)

**H-NUTR-008: Crop Rotation Systems** ⚪

```
  Norfolk 4-course rotation = tau(6) = 4
  Medieval 3-field system = divisor of 6

  Problem: CHERRY-PICKING from many systems.
  - 2-field system (also widely used) -- ignored
  - 5-course, 6-course, 7-course rotations exist
  - Selecting 3 and 4 from dozens of historical systems
    and matching them to divisor/tau(6) is post-hoc.
```

**H-NUTR-009: 6 Soil Horizons** ⚪

```
  USDA master horizons: O, A, E, B, C, R = 6
  is_perfect(6) = True

  Most robust "count = 6" match in this batch.
  USDA classification is well-standardized.

  BUT: Not all soils have all 6 (E often absent).
  Transitional horizons (AB, BC) exist.
  Still a human taxonomy, not a physical law.
```

**H-NUTR-010: Soil Texture Triangle** ⚪

```
  3 components (sand, silt, clay) = divisor of 6
  Balanced loam: ~1/3 each = meta fixed point

  Problem: ANY ternary system has 3 components.
  Equal partition of 3 always gives 1/3.
  This is a tautology, not a discovery.
```

**H-NUTR-011: Pollinator Dependence** ⚪

```
  ~75% of food crop species depend on pollinators (FAO)
  1 - ln(4/3) = 0.7123
  Difference: 3.8 percentage points

  Problem: The 75% figure has ENORMOUS uncertainty.
  - Klein et al. (2007): 35% by production volume
  - Estimates range from 35% to 87% by different metrics
  - With such spread, any target value can be "close"
```

**H-NUTR-012: Growing Seasons** ⚪

```
  Max natural growing seasons: ~3 (tropical)
  3 is divisor of 6

  Problem: Any integer 1-6 is a divisor of 6.
  Probability of random small integer being a divisor of 6:
  - 1,2,3,6 out of {1,2,3,4,5,6} = 4/6 = 67%
  - This test has almost no discriminating power.
```

### C. Food Science (H-NUTR-013 to 016)

**H-NUTR-013: Maillard Reaction** ⬛

```
  Onset ~140 C = 413.15 K
  140 = 4 * 5 * 7 (no factor of 6)
  No clean ratio to any TECS constant.
```

**H-NUTR-014: Fermentation Types** ⚪

```
  Listed 6 types: alcoholic, lactic, acetic, propionic, butyric, mixed acid
  Count = 6. But this selection is ARBITRARY.
  Additional types: citric acid, methane, butanediol, formic acid...
  You choose which are "main" and thus control the count.
```

**H-NUTR-015: Bread Ingredients** ⬛

```
  Basic bread: flour + water + yeast + salt = 4 (not 6)
  Flatbread: flour + water = 2
  Sugar and fat are enrichments. Factually incorrect to claim 6.
```

**H-NUTR-016: Preservation Methods** ⚪

```
  Listed 6: canning, drying, freezing, fermenting, salting, smoking
  But also: pickling, irradiation, vacuum packing, pasteurization,
            sugaring, chemical preservatives, UHT, HPP, MAP...
  Selection of exactly 6 is arbitrary.
```

### D. Human Metabolism (H-NUTR-017 to 020)

**H-NUTR-017: Thermic Effect of Food** ⬛

```
  TEF ~10% = 0.10
  phi(6)/sigma(6) = 2/12 = 0.1667 (67% off)
  1/sigma(6) = 1/12 = 0.0833 (17% off)
  No match. TEF also varies 0-30% by macronutrient.
```

**H-NUTR-018: Glycemic Index** ⬛

```
  GI thresholds: Low < 55, Medium 56-69, High > 70
  Golden Zone: [0.212, 0.500]
  No overlap between "optimal GI range" and Golden Zone.
  GI scale is arbitrary (glucose = 100 reference).
```

**H-NUTR-019: Harris-Benedict Coefficient** ⬛

```
  Male BMR: 66.5 + 13.75W + 5.003H - 6.755A
  |6.755 - 6| = 0.755 (12.6% error)
  Empirical regression coefficients from 1918.
  Mifflin-St Jeor (1990) uses different values entirely.
```

**H-NUTR-020: Body Composition** ⚪

```
  Protein: 16% vs 1/6 = 16.67% (diff 0.67%)
  Fat:     20% vs GZ_LOWER = 21.2% (diff 1.2%)
  Water:   60% vs 1-1/e = 63.2% (diff 3.2%)

  Closest match: protein ~ 1/6.
  But body protein ranges 10-20% depending on individual.
  With such wide biological variation, any target is "close".
```

## Texas Sharpshooter Analysis

```
  Hypotheses tested:              20
  Arithmetically passing:         13
  Non-trivial (structural) matches: 0
  Expected random matches at p=0.30: ~6
  Observed WHITE matches:         13

  p-value for 0 structural matches: N/A (nothing to test)
  Bonferroni threshold (20 tests):  alpha = 0.05/20 = 0.0025

  Conclusion: ZERO hypotheses survive Texas Sharpshooter test.
  All 13 passing results are WHITE (trivial/coincidental).
```

## Key Insight: Why Nutrition Fails Where Chemistry Succeeded

```
  Chemistry hypotheses: 10 GREEN, 8 ORANGE out of 30
  Nutrition hypotheses: 0 GREEN, 0 ORANGE out of 20

  Reason: CLASSIFICATION vs NATURAL LAW

  Chemistry:
  - Carbon Z=6 is a PHYSICAL FACT (6 protons, not a human choice)
  - Benzene C6H6 ring is FORCED by quantum mechanics
  - Bond angles are EXACT (deterministic physics)
  - sp3 = 4 orbitals is QUANTUM-MECHANICAL (not arbitrary)

  Nutrition:
  - "6 nutrient classes" is a TEXTBOOK CONVENTION (could be 5 or 7)
  - "6 taste types" depends on WHICH TASTES you count
  - "6 preservation methods" depends on WHERE you draw lines
  - Body composition VARIES by individual (10-40% body fat)
  - Crop rotation systems VARY by culture (2 to 8+ courses)

  The distinction: In chemistry, Nature chose 6.
  In nutrition, HUMANS chose 6 (or close to 6).
  Human classification choices are NOT evidence for
  the structural reality of perfect number 6.
```

## Limitations

1. All "count = 6" matches rely on human classification boundaries
2. Golden Zone width (28.8%) makes random hits likely
3. Small integers (1-6) are almost always divisors of 6 (4/6 chance)
4. Biological measurements have wide variance, enabling post-hoc matching
5. No hypothesis in this batch has any predictive power

## Verification Direction

This domain serves best as a **negative control**:
- If the TECS framework found strong matches here, it would suggest
  the framework matches anything (reducing credibility)
- Finding only WHITE/BLACK grades here STRENGTHENS confidence that
  the GREEN/ORANGE grades in chemistry and physics are meaningful
- Recommended: compare this null result against chemistry results
  to quantify the framework's discriminating power

## Conclusion

**No discoveries. No structural signal. All matches are coincidental.**
This is the expected and honest result for a domain where
the number 6 reflects human taxonomy rather than natural law.
