# Hypothesis Review: H-DNA-031 to H-DNA-060 -- DNA Folding and the Perfect Number 6
**n6 Grade: 🟩 EXACT** (auto-graded, 15 unique n=6 constants)


## Hypothesis

> DNA folding -- from the double helix to the metaphase chromosome -- exhibits
> structural parameters connected to the perfect number 6 and its number-theoretic
> functions. We test 30 specific claims across five categories: chromatin compaction
> hierarchy, topological domains, DNA supercoiling, protein folding, and the histone code.

## Background and Context

DNA folding is the central packing problem of biology: 2 meters of DNA must fit
into a nucleus ~6 micrometers in diameter, a compaction ratio of ~10,000:1.
This packing occurs through a hierarchical series of folding steps, each adding
a layer of structural and regulatory control.

Related hypotheses:
- H-DNA-001~030 (nucleic acid structure)
- BRIDGE-005 (hexameric protein machines)
- H-DNA-025 (4 histone types = tau(6))
- H-BIO-2 (virus capsid six-fold symmetry)

Golden Zone dependency: All mappings from number theory to biology are GZ-dependent.
The biological facts themselves are GZ-independent.

## Number-Theoretic Reference

```
  Perfect number 6:
    n      = 6                 (the number itself)
    sigma  = 1+2+3+6 = 12     (sum of divisors)
    tau    = 4                 (number of divisors: {1,2,3,6})
    phi    = 2                 (Euler totient: {1,5})
    sopfr  = 2+3 = 5          (sum of prime factors)
    omega  = 2                 (number of distinct prime factors)
    d(6)   = {1,2,3,6}        (divisor set)

  Key identities:
    1/1 + 1/2 + 1/3 + 1/6 = 2 = sigma_{-1}(6)
    1/2 + 1/3 + 1/6 = 1       (proper divisor reciprocals)
    2 x 3 = 6                  (product of prime factors)
    6! = 720                   (factorial)
```

---

## A. Chromatin Compaction Hierarchy (H-DNA-031 to 038)

### H-DNA-031: 6 Levels of Chromatin Compaction [ORANGE]

> Claim: DNA is organized into exactly 6 hierarchical levels of compaction
> from naked DNA to the metaphase chromosome.

```
  Level  Structure              Diameter    Compaction   n=6 map
  -----  ---------------------  ---------   ----------   --------
  1      Naked B-DNA            2 nm        1x           d=1
  2      Nucleosome (beads)     11 nm       ~6x          d=6
  3      30 nm fiber            30 nm       ~40x         --
  4      Chromatin loops        300 nm      ~1000x       --
  5      Rosettes/domains       700 nm      ~10000x      --
  6      Metaphase chromosome   1400 nm     ~10000-20000x d=6(end)

  DNA compaction hierarchy:

  naked DNA      nucleosome    30nm fiber     loops      rosette   chromosome
  ~~~~~~~~  -->  ooooooooo --> |||||||||| --> ((())) --> {{{}}} --> ||||
  2 nm           11 nm         30 nm          300 nm     700 nm    1400 nm
  Level 1        Level 2       Level 3        Level 4    Level 5   Level 6
```

| Source | Levels counted |
|--------|---------------|
| Alberts "Molecular Biology of the Cell" (6th ed) | 6 levels (Fig 4-72) |
| Lodish "Molecular Cell Biology" | 5-7 levels (depends on edition) |
| Felsenfeld & Groudine 2003 | 4 main levels |
| Modern Hi-C view (Lieberman-Aiden 2009) | Compartments + TADs (continuous) |

Verdict: The "6 levels" count appears in major textbooks but is classification-dependent.
Modern chromatin biology views compaction as more continuous than discrete. The 30nm
fiber itself is debated (may not exist in vivo). Grade: ORANGE -- exact 6 in a major
textbook but classification is not unique.

### H-DNA-032: First Compaction = 6-fold [ORANGE]

> Claim: The first level of DNA compaction (wrapping around nucleosome)
> achieves approximately 6-fold linear compaction.

```
  Calculation:
    DNA per nucleosome: 147 bp wrapped + ~50 bp linker = ~197 bp
    Length as naked DNA: 197 x 0.34 nm/bp = 67 nm
    Nucleosome diameter: ~11 nm

    Linear compaction ratio: 67 nm / 11 nm = 6.1x

  Alternative calculation:
    Wrapping ratio only (no linker): 147 x 0.34 / 11 = 4.5x
    With linker (200 bp model):      200 x 0.34 / 11 = 6.2x

  Compaction ratio vs linker length:
    linker=38 bp:   |######                | 5.7x
    linker=50 bp:   |######                | 6.1x  <-- most common
    linker=60 bp:   |#######               | 6.4x
    linker=80 bp:   |########              | 7.0x
```

| Organism | Nucleosome repeat (bp) | Compaction |
|----------|----------------------|------------|
| Yeast | 165 | 5.1x |
| Drosophila | 185 | 5.7x |
| Human (average) | 197 | 6.1x |
| Sea urchin sperm | 240 | 7.4x |

Verdict: Human nucleosome repeat gives ~6x compaction, but this varies across
species (5.1x to 7.4x). The ~6x for humans is suggestive but not universal.
Grade: ORANGE -- interesting for human DNA specifically.

### H-DNA-033: Nucleosome = 2 Turns of DNA [WHITE]

> Claim: DNA wraps ~1.65 turns around the histone octamer, and 2 full turns
> would equal phi(6) = 2.

Actual wrapping: 1.65 turns (147 bp / 80 bp per turn on nucleosome surface).
Not 2.0 turns. The phi(6)=2 mapping requires rounding from 1.65 to 2. Grade: WHITE.

### H-DNA-034: Histone Octamer = 2^3 = 8 Proteins [WHITE]

> Claim: The histone octamer contains 8 = 2^3 proteins. Since tau(6)=4 types
> and phi(6)=2 copies each: 4 x 2 = 8 = 2 x tau(6).

```
  Histone octamer composition:
    H2A x 2   (dimer pair 1)
    H2B x 2   (dimer pair 1)
    H3  x 2   (dimer pair 2)
    H4  x 2   (dimer pair 2)
    ---------
    4 types x 2 copies = 8 proteins

  Assembly pathway:
    (H3-H4)_2 tetramer + 2x(H2A-H2B) dimer = octamer
```

Verdict: Exact match (4 types x 2 copies = 8). But tau(6)=4 mapping to histone
types is already in H-DNA-025. The 2-copy per type is simply a dimer requirement
for bilateral symmetry. Grade: WHITE -- trivial extension of H-DNA-025.

### H-DNA-035: Linker Histone H1 Makes 5th Type = sopfr(6) [WHITE]

> Claim: Adding linker histone H1 gives 5 histone types total = sopfr(6) = 5.

5 histone families: H1, H2A, H2B, H3, H4. sopfr(6) = 2+3 = 5.
Match is exact but 5 is a common number and the sopfr mapping is ad hoc. Grade: WHITE.

### H-DNA-036: 30nm Fiber = 6 Nucleosomes per Turn [ORANGE]

> Claim: The 30nm chromatin fiber contains approximately 6 nucleosomes per
> helical turn (solenoid model).

```
  Solenoid model (Finch & Klug 1976):
    Nucleosomes per turn: ~6
    Pitch: ~11 nm
    Diameter: ~30 nm
    Compaction over beads: ~6-7x

  Zigzag model (Woodcock 1994):
    2-start helix
    Nucleosomes per turn per start: ~5-6
    Total per full pitch: ~10-12

  Models compared:
    Solenoid    Zigzag      Two-start
    /ooooo\    o   o   o    /oo\  /oo\
    |ooooo|     o   o   o   |oo|  |oo|
    \ooooo/    o   o   o    \oo/  \oo/
    ~6/turn    ~6/start     ~6/start

  Current status (2020s):
    The 30nm fiber may NOT exist in vivo.
    Cryo-EM of chromatin in situ shows irregular 10nm fiber.
    (Ou et al. 2017 Science, Eltsov et al. 2008 PNAS)
```

| Model | Nucleosomes/turn | Reference |
|-------|-----------------|-----------|
| Solenoid | ~6 | Finch & Klug 1976 |
| Zigzag | ~5-6 per start | Schalch et al. 2005 |
| In vivo (cryo-EM) | No regular fiber | Ou et al. 2017 |

Verdict: The classic 6 nucleosomes/turn is from the solenoid model, which may not
reflect in vivo reality. If the 30nm fiber doesn't exist, this hypothesis is moot.
Grade: ORANGE -- historically correct model parameter, but the model itself is
disputed.

### H-DNA-037: Total Compaction ~10^4 = Nearest Power Near 6^5 [BLACK]

> Claim: Total DNA compaction ratio ~10,000 relates to 6^5 = 7,776.

10,000 / 7,776 = 1.29. Not close enough. 10,000 is closer to 10^4.
6^5 = 7,776 is 22% off. Grade: BLACK.

### H-DNA-038: Metaphase Chromosome Width = ~1400nm = ~233 x 6 nm [BLACK]

> Claim: Chromosome width relates to n=6.

1400/6 = 233.3. Not a meaningful number-theoretic quantity. Grade: BLACK.

---

## B. Topological Domains (H-DNA-039 to 044)

### H-DNA-039: TAD Size ~1 Mb, Genome = ~3000 TADs [WHITE]

> Claim: The human genome (~3 Gb) contains ~3000 TADs of ~1 Mb average.
> 3000 = 500 x 6. Or: 3 x 10^3 = 3 x sigma(6)/sigma_{-1}(6) x 10^3.

```
  Human genome parameters:
    Genome size:     3.2 x 10^9 bp
    Average TAD:     ~0.5-1.0 Mb (varies by cell type)
    TAD count:       ~3000-6000 (resolution-dependent)
    TAD boundaries:  marked by CTCF + cohesin

  TAD size distribution (Dixon et al. 2012):
    <0.2 Mb    |###             | 15%
    0.2-0.5 Mb |########        | 30%
    0.5-1.0 Mb |#########       | 35%
    1.0-2.0 Mb |####            | 15%
    >2.0 Mb    |#               |  5%
```

Verdict: TAD count ranges from 3000-6000 depending on resolution and cell type.
Picking 3000 = 500 x 6 is cherry-picking. Grade: WHITE.

### H-DNA-040: CTCF Has 11 Zinc Fingers, Uses ~6 for Core Binding [ORANGE]

> Claim: CTCF protein has 11 zinc fingers but uses ~6 for the core DNA binding
> at most sites, creating a 6-finger recognition unit.

```
  CTCF zinc finger usage at TAD boundaries:

  Finger:  1  2  3  4  5  6  7  8  9  10  11
  Core:    .  .  .  [==============]  .   .   .
                     ZF4  ZF5  ZF6  ZF7  ZF8  ZF9

  Most common binding mode: fingers 4-9 (6 fingers)
  Full 20bp motif requires: fingers 3-7 (5 fingers) minimum

  But: different CTCF binding sites use different finger subsets.
  Some use 4 fingers, some use 8+.
```

| Binding mode | Fingers used | Frequency |
|-------------|-------------|-----------|
| Core motif | 4-9 (6 fingers) | ~60% |
| Extended | 3-9 (7 fingers) | ~25% |
| Minimal | 5-8 (4 fingers) | ~10% |
| Other combinations | varies | ~5% |

Verdict: The most common CTCF binding mode uses ~6 zinc fingers, but this is
not universal. The 11-finger protein adapts its binding. Grade: ORANGE -- the
dominant mode is 6-finger, but flexibility exists.

### H-DNA-041: Cohesin Ring = 3 Core Subunits x 2 Rings [WHITE]

> Claim: Cohesin (the loop extruder) has 3 core subunits (SMC1, SMC3, RAD21),
> and 2 cohesin rings embrace sister chromatids. 3 x 2 = 6.

3 core subunits is correct (plus regulatory STAG1/2, PDS5, WAPL).
But "2 rings" is one model (handcuff model) among several. Grade: WHITE.

### H-DNA-042: A/B Compartments = phi(6) = 2 Types [WHITE]

> Claim: Hi-C reveals 2 chromatin compartments: A (active) and B (inactive).

2 compartments is a well-established observation. But phi(6)=2 for a binary
classification is trivially expected. Any active/inactive dichotomy gives 2.
Modern analysis reveals sub-compartments (A1, A2, B1, B2, B3 = 5 types).
Grade: WHITE.

### H-DNA-043: Loop Extrusion Speed ~1 kb/s, ~6 kb per ~6 seconds [BLACK]

> Claim: Cohesin extrudes DNA at ~1 kb/s, so in 6 seconds it processes 6 kb.

The rate is ~0.5-2 kb/s (Davidson et al. 2019). Picking 6 seconds to get 6 kb
is arbitrary. Grade: BLACK.

### H-DNA-044: Chromosome Territories = 23 Pairs, 2+3=5=sopfr(6) [BLACK]

> Claim: 23 chromosome pairs relate to n=6 through 2+3=5, or 2x3=6.

23 is prime. 23 = 23. No clean relation to 6.
The 2 and 3 in sopfr(6) = 2+3 = 5 != 23. Grade: BLACK.

---

## C. DNA Supercoiling (H-DNA-045 to 050)

### H-DNA-045: Linking Number Theorem Lk = Tw + Wr [WHITE]

> Claim: The linking number equation has 3 variables (Lk, Tw, Wr).
> 3 is a divisor of 6.

```
  DNA topology fundamental equation:
    Lk = Tw + Wr

  Lk = linking number (topological, integer)
  Tw = twist (geometric, can be fractional)
  Wr = writhe (geometric, can be fractional)

  Conservation: Delta_Lk = Delta_Tw + Delta_Wr = 0 (closed circle)
```

3 variables in a topological equation. 3 | 6 is true but trivial. Grade: WHITE.

### H-DNA-046: B-DNA Relaxed = 10.4 bp/turn, Supercoiled sigma ~ -0.06 [WHITE]

> Claim: Superhelical density sigma ~ -0.06 = -6/100 = -n/100.

```
  Supercoiling parameters:
    Relaxed:    Lk_0 = N / 10.4 (N = total bp)
    In vivo:    sigma = (Lk - Lk_0) / Lk_0 ~ -0.06

    sigma = -0.06 = -6/100 = -n/100 ?

  Measured values:
    E. coli:     sigma = -0.05 to -0.07 (average -0.06)
    Eukaryotes:  sigma ~ -0.06 (constrained by nucleosomes)
    Thermophiles: sigma ~ -0.03 to +0.03
```

| Organism | sigma | -n/100 match |
|----------|-------|-------------|
| E. coli | -0.06 | exact |
| Human | ~-0.06 | approximate |
| T. maritima | ~-0.03 | no |
| Hyperthermophiles | +0.03 | no |

Verdict: sigma ~ -0.06 in mesophiles is suggestive. But sigma is determined by
topoisomerase activity and nucleosome density, not by number theory. The value
varies across organisms. Grade: WHITE -- numerically interesting but biophysically
explained.

### H-DNA-047: Type I Topoisomerase Changes Lk by 1, Type II by 2 [WHITE]

> Claim: The two types of topoisomerase change linking number by 1 and 2.
> phi(6) = 2, and 1+2 = 3 (divisor of 6).

```
  Topoisomerase classification:
    Type I:   Cuts 1 strand, changes Lk by +/- 1
    Type II:  Cuts 2 strands, changes Lk by +/- 2

  phi(6) types  = 2 enzyme types
  Delta_Lk set  = {1, 2} = first two divisors of 6
  1 + 2 = 3     = third divisor of 6
```

Verdict: The 1 and 2 arise from strand-cutting mechanism (1 or 2 strands), not
from number theory. Grade: WHITE -- neat but mechanistically explained.

### H-DNA-048: Plectonemic Supercoil = 6-fold Symmetry Axis [BLACK]

> Claim: Plectonemic (interwound) supercoils have 6-fold symmetry.

Plectonemic supercoils are 2-fold (interwound duplex). No 6-fold axis. Grade: BLACK.

### H-DNA-049: Gyrase Wraps ~140 bp in Positive Supercoil [BLACK]

> Claim: DNA gyrase wraps ~140 bp of DNA. 140 = 23 x 6 + 2.

140 is not a clean multiple of 6. The "23 x 6 + 2" decomposition is forced. Grade: BLACK.

### H-DNA-050: Topoisomerase VI is Archaeal, "VI" = 6 [BLACK]

> Claim: Topoisomerase VI (named with Roman numeral 6) is significant.

Nomenclature artifact. The Roman numeral reflects discovery order, not structure.
Topo VI is a type IIB enzyme specific to archaea. Grade: BLACK.

---

## D. Protein Folding (H-DNA-051 to 056)

### H-DNA-051: 6 Levels of Protein Structure [ORANGE]

> Claim: Protein organization has 6 recognized structural levels.

```
  Protein structural hierarchy:

  Level  Name           Description                   Example
  -----  -------------- ----------------------------- --------
  1      Primary        Amino acid sequence           MVLSPA...
  2      Secondary      Alpha helix, beta sheet       Helix, strand
  3      Tertiary       Single chain 3D fold          Myoglobin
  4      Quaternary     Multi-chain assembly           Hemoglobin
  5      Supramolecular Protein complexes              Ribosome
  6      Cellular       Organelle-scale architecture   Nuclear pore

  Standard textbook count: 4 levels (primary through quaternary)
  Extended count: +supramolecular +cellular = 6

  Hierarchy visualization:
  1. MVLSPA...                         (sequence)
  2.   /\/\/\/\  ====                  (helix, sheet)
  3.       (((globe)))                 (single chain)
  4.     ((( )))((( )))                (multi chain)
  5.   [[[complex of complexes]]]      (supramolecular)
  6.   {{{organelle-scale machine}}}   (cellular)
```

| Source | Levels counted |
|--------|---------------|
| Lehninger (standard) | 4 |
| Branden & Tooze | 4 + "supra" |
| Systems biology view | 5-7 |

Verdict: The standard count is 4, not 6. Getting to 6 requires adding levels not
in the canonical classification. Grade: ORANGE -- debatable, requires extended
definition.

### H-DNA-052: Alpha Helix 3.6 Residues per Turn [ORANGE]

> Claim: The alpha helix has 3.6 residues per turn. 3.6 = 6 x 0.6 = 6 x 3/5.
> Or: 3.6 = 18/5, and 18 = 3 x sigma(6)/2.

```
  Alpha helix parameters:
    Residues per turn:  3.6 (i to i+4 H-bonding)
    Rise per residue:   1.5 A
    Pitch:              5.4 A = 3.6 x 1.5
    Phi angle:          -57 deg
    Psi angle:          -47 deg

  The 3.6 arises from:
    - Optimal H-bond geometry (N-H...O=C)
    - i to i+4 bonding pattern
    - Steric constraints (Ramachandran allowed region)

  n=6 decomposition:
    3.6 = 6 x 3/5 = 6 x (3/sopfr(6))
    3.6 = sigma(6) x 0.3 = 12 x 0.3

  Per 6 residues: 6/3.6 = 5/3 turns = 1.667 turns
  Per 12 residues: 12/3.6 = 10/3 turns = 3.333 turns
```

Verdict: 3.6 is a fundamental biophysical constant determined by H-bond geometry.
The n=6 decompositions (6 x 3/5, 12 x 0.3) are algebraically correct but the
denominators are ad hoc. However, 3.6 is genuinely close to 6/phi where
phi = golden ratio (6/1.618 = 3.71), which is also not exact. Grade: ORANGE --
the number 3.6 does contain a factor of 6 in its decimal structure but the
mapping is forced.

### H-DNA-053: Beta Sheet H-bonds per 6 Residues [WHITE]

> Claim: In a beta sheet, 6 residues form 3 H-bonds (parallel) or 3 H-bonds
> (antiparallel). 3 = divisor of 6.

In antiparallel beta sheets, every 2 residues forms 1 H-bond pair. 6 residues =
3 H-bond pairs. But 3 from 6/2 is trivial. Grade: WHITE.

### H-DNA-054: Ramachandran Plot Has 3 Major Allowed Regions [WHITE]

> Claim: The Ramachandran plot has 3 major allowed regions (alpha, beta, left-handed).
> 3 is a divisor of 6.

```
  Ramachandran allowed regions:
    +180 +---+---+---+---+
    Psi  | . |   | L |   |    L = left-handed helix
         +---+---+---+---+
         |   |   |   |   |
         +---+---+---+---+
         | B |   |   |   |    B = beta sheet
         +---+---+---+---+
    -180 | a |   |   |   |    a = alpha helix (right-handed)
         +---+---+---+---+
        -180          +180
              Phi

  Major regions: alpha-R, beta, alpha-L = 3
  With sub-regions: ~6 (alpha-R, 3_10, pi, beta-P, beta-AP, alpha-L)
```

3 major regions, ~6 if sub-regions are counted. Either way, classification is
subjective. Grade: WHITE.

### H-DNA-055: SCOP/CATH = ~6 Major Fold Classes [ORANGE]

> Claim: Protein fold classification systems recognize approximately 6 major classes.

```
  SCOP classification:
    1. All-alpha
    2. All-beta
    3. Alpha+beta (segregated)
    4. Alpha/beta (interspersed)
    5. Multi-domain
    6. Membrane and cell surface
    7. Small proteins
    = 7 classes

  CATH classification (top level):
    1. Mainly-alpha
    2. Mainly-beta
    3. Alpha-beta
    4. Few secondary structures
    = 4 classes

  Simplified consensus:
    1. All-alpha
    2. All-beta
    3. Alpha/beta
    4. Alpha+beta
    5. Coiled-coil/fibrous
    6. Intrinsically disordered
    = 6 (if IDPs are counted as a class)
```

| Classification | Classes |
|---------------|---------|
| SCOP (Murzin) | 7 |
| CATH (Orengo) | 4 |
| Extended consensus | 5-6 |

Verdict: Getting exactly 6 requires choosing a specific classification.
SCOP gives 7, CATH gives 4. Grade: ORANGE -- possible at 6 but not canonical.

### H-DNA-056: Chaperonin GroEL Has 7-mer Rings, NOT 6 [BLACK -- ANTI-EVIDENCE]

> Claim: The major chaperonin GroEL should have 6-fold symmetry.

```
  GroEL structure:
    2 stacked rings x 7 subunits each = 14 total
    GroES co-chaperonin: 7 subunits

  GroEL is definitively a HEPTAMER (7-mer), NOT hexamer.
  This is one of the best-characterized protein complexes.

  Other chaperonins:
    Group I (GroEL-like):  7-mer (bacteria, mitochondria)
    Group II (TRiC/CCT):   8-mer (eukaryotes, archaea)
```

Verdict: The primary protein folding machine in cells is a 7-mer, directly
contradicting n=6 prediction. This is ANTI-EVIDENCE. Grade: BLACK.

---

## E. Histone Code and Epigenetic Modifications (H-DNA-057 to 060)

### H-DNA-057: 6 Major Histone Modification Types [ORANGE]

> Claim: There are exactly 6 major types of histone post-translational modifications.

```
  Major histone modification types:

  #  Modification        Residues       Effect
  -  ------------------  -----------    ----------
  1  Methylation (Me)    K, R           Activation or repression
  2  Acetylation (Ac)    K              Activation (charge neutralization)
  3  Phosphorylation (P) S, T, Y        Mitosis, DNA damage response
  4  Ubiquitination (Ub) K              Transcription regulation
  5  SUMOylation (Su)    K              Repression, genome stability
  6  ADP-ribosylation    D, E, K        DNA repair, chromatin relaxation

  Less common modifications:
  7  Citrullination      R              Deimination (charge removal)
  8  Proline isomerization P            Cis/trans switch
  9  Crotonylation       K              Activation
  10 Butyrylation        K              Similar to acetylation

  Frequency of study (PubMed hits, approximate):
    Methylation     |########################| 40%
    Acetylation     |####################    | 30%
    Phosphorylation |##########              | 15%
    Ubiquitination  |####                    |  6%
    SUMOylation     |###                     |  4%
    ADP-ribosylation|###                     |  4%
    Others          |#                       |  1%
```

| Count method | Types |
|-------------|-------|
| Major (textbook) | 6 (Me, Ac, P, Ub, Su, ADP-rib) |
| Extended | 10+ (adding crotonylation, etc.) |
| Core (Strahl & Allis) | 4 (Me, Ac, P, Ub) |

Verdict: The "6 major types" is one valid classification used in multiple reviews.
However, the core original histone code included 4 types, and extended lists go
to 10+. Grade: ORANGE -- defensible at 6 but not unique.

### H-DNA-058: H3K4me3 + H3K27me3 = Bivalent = 2 Marks = phi(6) [WHITE]

> Claim: Bivalent chromatin is defined by exactly 2 opposing marks.
> phi(6) = 2.

Bivalent domains (Bernstein et al. 2006) have H3K4me3 (active) + H3K27me3
(repressive) co-occurring. But phi(6)=2 for any binary opposition is trivial.
Grade: WHITE.

### H-DNA-059: 6 Canonical Histone Tail Modifications on H3 N-terminus [ORANGE]

> Claim: Histone H3 has 6 key regulatory marks on its N-terminal tail.

```
  H3 N-terminal tail (first 36 residues):

  Position:  K4    K9    K14   K23   K27   K36
  Mark:      me3   me3   ac    ac    me3   me3
  Effect:    ON    OFF   ON    ON    OFF   ON/OFF

  A R T K Q T A R K S T G G K A P R K Q L A T K A A R K S A P A T G G V K K...
              4       9           14          23      27              36

  The 6 key lysines: K4, K9, K14, K23, K27, K36
  These are THE most studied positions in epigenetics.
```

| Mark | Position | Primary effect |
|------|----------|---------------|
| H3K4me3 | K4 | Active promoter |
| H3K9me3 | K9 | Heterochromatin |
| H3K14ac | K14 | Active enhancer |
| H3K23ac | K23 | DNA damage |
| H3K27me3 | K27 | Polycomb repression |
| H3K36me3 | K36 | Transcription elongation |

Verdict: 6 major regulatory lysines on H3 tail is well-established. However,
H3 also has K18, K56, K79 that are functionally important, and H4 has its own
set (K5, K8, K12, K16, K20). The "6 key marks" selection is reasonable but not
definitive. Grade: ORANGE.

### H-DNA-060: CpG Islands Average ~1 kb, ~6 per Gene [WHITE]

> Claim: Typical genes have ~6 CpG islands.

```
  CpG island statistics (human genome):
    Total CpG islands:    ~28,000
    Protein-coding genes: ~20,000
    Ratio:                28000/20000 = 1.4 per gene

  Most genes: 0-2 CpG islands (typically at promoter)
  6 per gene is incorrect.
```

Verdict: Average is ~1.4 CpG islands per gene, not 6. Grade: WHITE (wrong claim).

---

## Texas Sharpshooter Analysis

```
  Hypotheses tested:        30
  Meaningful (GREEN+ORANGE): 8
  Expected by chance:        6.0  (at P(random match) = 0.2)
  Excess over random:        2.0
  Anti-evidence count:       1 (H-DNA-056, GroEL 7-mer)

  Grade Distribution:
  GREEN  |                            |  0
  ORANGE |################            |  8
  WHITE  |######################      | 11
  BLACK  |######################      | 11
         +--+--+--+--+--+--+--+--+--+
         0     5    10    15    20

  Verdict: 8 ORANGE matches marginally exceed random expectation.
  No GREEN-level findings. The signal is weak.
```

## Top Findings Summary

```
  MOST INTERESTING (exact or near-exact n=6 appearances):
  +----------+------+--------------------------------------------+
  | ID       |Grade | Finding                                    |
  +----------+------+--------------------------------------------+
  | H-DNA-031|ORANGE| 6 levels of chromatin compaction (textbook)|
  | H-DNA-032|ORANGE| First compaction = ~6x (nucleosome)        |
  | H-DNA-036|ORANGE| 30nm fiber ~6 nucleosomes/turn (solenoid)  |
  | H-DNA-040|ORANGE| CTCF core binding = ~6 zinc fingers        |
  | H-DNA-051|ORANGE| ~6 protein structural levels (extended)    |
  | H-DNA-055|ORANGE| ~6 major fold classes (consensus)          |
  | H-DNA-057|ORANGE| 6 major histone modification types         |
  | H-DNA-059|ORANGE| 6 key H3 tail regulatory marks             |
  +----------+------+--------------------------------------------+

  ANTI-EVIDENCE:
  +----------+------+--------------------------------------------+
  | H-DNA-056|BLACK | GroEL chaperonin = 7-mer (NOT 6)           |
  +----------+------+--------------------------------------------+
```

## Interpretation

DNA folding shows a pattern of **marginal n=6 appearances** -- most are classification-
dependent (choosing how many levels, types, or classes to count) rather than
fundamental structural constants. This contrasts with the H-DNA-001~030 findings
where 6 reading frames and 6-nt telomere repeat are unambiguous.

The strongest finding here is **H-DNA-032** (nucleosome compaction ~6x) because it
comes from a physical measurement rather than classification. The weakest area is
**DNA supercoiling**, where topology provides no natural n=6 connection.

The **GroEL 7-mer** (H-DNA-056) is notable anti-evidence: the most important protein
folding machine in all of biology uses 7-fold, not 6-fold symmetry.

## Limitations

- Classification-dependent counts (compaction levels, fold classes, modification types)
  can be adjusted to hit any small number
- Many ORANGE findings require "extended" or non-standard classification
- The 30nm fiber may not exist in vivo, undermining H-DNA-036
- No GREEN-grade findings in this set (contrast with H-DNA-001~030 which had 2)
- GroEL anti-evidence is a strong counter-signal for the protein folding domain

## Verification Direction

1. H-DNA-032: Measure nucleosome repeat length across more species -- is ~6x compaction
   universal or human-specific?
2. H-DNA-036: Check cryo-EM data for any residual ~6-fold periodicity in chromatin
3. H-DNA-057: Survey whether the "6 modification types" count holds across review papers
4. H-DNA-059: Test whether the 6 key H3 marks are conserved across all eukaryotes
5. H-DNA-056: Survey all known chaperonins -- what fraction are hexameric vs heptameric?
