# Hypothesis Review 411: Speed of Light = Maximum Clock Speed (H-SIM-4)

## Hypothesis

> The speed of light c is the simulator's maximum processing speed: one Planck cell
> per Planck tick. Lorentz invariance emerges as a consistency requirement of the
> computational substrate. The causal structure of spacetime (light cones) is
> equivalent to BFS wavefront propagation on a Planck-scale grid graph.

## Background / Context

Digital physics interprets physical laws as computational rules on a discrete lattice.
Konrad Zuse (1969) first proposed "Rechnender Raum" (computing space). Fredkin (1990)
developed reversible cellular automata models. Seth Lloyd (2002) computed the universe's
maximum computational capacity. Wolfram (2002) explored cellular automaton physics.

The key observation: in Planck units, c = hbar = G = 1. This means c = lp/tp = 1,
i.e., information traverses exactly one grid cell per clock tick. This is the maximum
speed on any lattice: the BFS wavefront speed.

Related hypotheses: 410 (H-SIM-3, precision bits), 172 (G*I=D*P conservation),
CLAUDE.md amplification constant A(pi)=17.

## Core Calculation

### 1. c = lp/tp (Exact by Definition)

```
  c (defined)   = 2.99792458e+08 m/s
  lp / tp       = 2.99792458e+08 m/s
  Difference    = 0.000 m/s
  Relative err  = 0.000

  In Planck units:
    c    = 1  (speed)
    hbar = 1  (action)
    G    = 1  (gravity)
    lp   = 1  (length)
    tp   = 1  (time)

  Interpretation: c = 1 cell/tick is the DEFINITION of Planck units.
  This is a tautology, but the physical interpretation is nontrivial:
    "No information can propagate faster than 1 grid cell per clock cycle"
```

### 2. Causal Structure = BFS Wavefront

```
  Light cone in 1+1D spacetime (Planck units, c=1):

         t (ticks)
         ^
     5   |   *           *
     4   |    *         *
     3   |     *       *
     2   |      *     *
     1   |       *   *
     0   +--------*---------> x (cells)
              -5  0  5

  Each tick: wavefront expands by exactly 1 cell in each direction
  This IS Breadth-First Search on a grid graph
  BFS wavefront speed = 1 cell/tick = c
  Anything outside the cone = causally disconnected = unreachable by BFS
```

### 3. Lorentz Factor as Computational Budget

```
  gamma = 1/sqrt(1 - v^2/c^2)     (SI)
  gamma = 1/sqrt(1 - v_grid^2)    (Planck units, c=1)

  v_grid   gamma    time_dilation   Interpretation
  -------  -------  -------------   --------------------------------
   0.0000    1.000       1.000      All budget for internal evolution
   0.1000    1.005       0.995      ~0.5% budget spent on movement
   0.5000    1.155       0.866      13.4% budget spent on movement
   0.8000    1.667       0.600      40% budget spent on movement
   0.9000    2.294       0.436      56.4% budget spent on movement
   0.9900    7.089       0.141      85.9% budget spent on movement
   0.9990   22.366       0.045      95.5% budget spent on movement
   0.9999   70.712       0.014      98.6% budget spent on movement
   1.0000      inf       0.000      100% budget = no internal evolution

  At v = c: all computation is consumed by spatial propagation
  --> No ticks remain for internal state evolution
  --> Time dilation = computational resource allocation
  --> Massless particles (photons): v=c, no internal clock, no rest frame
```

### 4. Universe Computational Capacity

```
  Grid operations per second:
    N_cells = R/lp = 2.722e+61 (per axis)
    N_cells^3      = 2.018e+184 (spatial volume)
    Clock rate     = 1/tp = 1.855e+43 ticks/s
    Grid_ops       = 3.742e+227 ops/s

  Comparison with known limits:

  System                        log10(ops/s)  Bar
  ---------------------------  ------------  -------------------------
  Human brain                          16.0  ##
  Frontier supercomputer               18.2  ###
  All computers on Earth               21.0  ###
  Bremermann limit (1 kg)              50.9  ########
  Lloyd limit (universe)              103.9  ##################
  Bremermann limit (universe)         104.1  ##################
  Grid ops (universe)                 227.6  ########################################

  Grid_ops / Bremermann_total = 2.93e+123

  --> The grid operations EXCEED the Bremermann limit by 10^123
  --> A universe cannot simulate itself at Planck resolution
  --> Consistent with: the simulator must be LARGER than the simulated
  --> Alternatively: the universe does NOT simulate every Planck cell
      (holographic principle: information is on the BOUNDARY, not volume)
```

### 5. Bekenstein Bound Comparison

```
  Bekenstein bound:
    I_max = 2*pi*R*M*c/(hbar*ln2) = 1.701e+123 bits
    log10(I_max) = 123.2

  Grid bits (1 bit/cell):
    N^3 = 2.018e+184 bits
    log10 = 184.3

  Bekenstein / Grid = 8.43e-62

  --> Bekenstein bound is 10^61 LESS than naive grid
  --> The universe stores information holographically (surface, not volume)
  --> Volume/Surface ratio: N^3/N^2 = N = 2.7e61 ~ 10^61  (matches!)
  --> This is the holographic principle: I ~ R^2, not R^3
```

### 6. Powers of c

```
  c^(1/n) for TECS-L-relevant n:

    c^(1/  2) =  17314.52   (not nice)
    c^(1/  3) =    669.28   (not nice)
    c^(1/  6) =     25.87   (not nice)
    c^(1/ 12) =      5.09   (close to 5, but not exact)
    c^(1/ 17) =      3.15   (close to pi? no, 3.15 vs 3.14159)
    c^(1/ 34) =      1.78   (not nice)
    c^(1/204) =      1.10   (not nice)

  ln(c) = 19.52
  log10(c) = 8.477
  log2(c) = 28.16

  299792458 = 2 x 7 x 21413747 (21413747 is prime)
  --> c in SI has no nice factorization (expected: SI units are human-defined)
  --> In Planck units c = 1, which IS the nicest possible value
```

## ASCII Graph: Computational Hierarchy

```
  log10(ops/s)
  0        50       100      150      200      228
  |--------|--------|--------|--------|--------|
  |
  |##                    Human brain (10^16)
  |
  |###                   Frontier (10^18.2)
  |
  |####                  All Earth computers (10^21)
  |
  |##########            Bremermann 1kg (10^50.9)
  |
  |####################  Bremermann universe (10^104)
  |                      Lloyd universe (10^103.9)
  |
  |                                    Bekenstein bits (10^123)
  |
  |########################################  Grid ops (10^227.6)
  |
  |========================================
  0                     104          184  228
                         |            |    |
                    Bremermann    Grid   Grid
                     (mass)      bits   ops/s

  GAP: 10^123 between Bremermann and Grid ops
  = Bekenstein bound ~ 10^123 bits
  --> Holographic principle: universe uses surface, not volume
```

## ASCII Graph: Time Dilation as Computation Budget

```
  Internal clock rate (fraction of rest rate)
  1.0 |*
      | *
  0.8 |   *
      |     *
  0.6 |       *
      |          *
  0.4 |             *
      |                *
  0.2 |                    *
      |                        *
  0.0 +----+----+----+----+----*---> v/c
      0.0  0.2  0.4  0.6  0.8  1.0

  Curve: f(v) = sqrt(1 - v^2)
  At v=0: 100% budget for internal evolution
  At v=c: 0% budget (all spent on movement)
  Photons live at v=c: no internal clock, no rest frame, no aging
```

## 해석 (Interpretation)

1. **c = lp/tp = 1은 플랑크 단위의 정의에 내재된 항등식이다.** 이것 자체는 새로운
   발견이 아니다. 하지만 "격자의 최대 전파 속도 = 1 셀/틱"이라는 해석은 물리적으로
   의미가 있다. 모든 셀룰러 오토마타에서 정보 전파 속도에는 상한이 있으며, 이것이
   광속이 된다.

2. **로렌츠 불변성은 계산 자원 배분의 필연적 결과이다.** 속도 v로 이동하는 객체는
   계산 예산의 일부를 공간 이동에 소비한다. 남은 예산이 내부 상태 진화(= 시간)에
   사용된다. 이것이 시간 지연이다. v = c에서는 모든 예산이 이동에 소비되어 내부
   시계가 정지한다.

3. **그리드 연산량이 Bremermann 한계를 10^123배 초과한다.** 이것은 우주가 자기
   자신을 플랑크 해상도로 시뮬레이션할 수 없음을 의미한다. 두 가지 해석이 가능하다:
   (a) 시뮬레이터가 우주보다 훨씬 크거나, (b) 우주는 모든 플랑크 셀을 시뮬레이션하지
   않는다 (홀로그래피 원리: 정보는 부피가 아닌 표면에 있다).

4. **10^123 갭은 Bekenstein 한계와 정확히 일치한다.** 이것은 우연이 아니다:
   Bekenstein ~ R^2 / lp^2 ~ N^2, Grid ~ N^3이므로 비율은 N ~ R/lp ~ 10^61이다.
   이것은 홀로그래피 원리의 또 다른 표현이다.

5. **c의 SI 값(299792458)에는 특별한 수론적 구조가 없다.** 이는 미터와 초가
   인간이 정의한 단위이기 때문에 예상되는 결과이다. 플랑크 단위에서 c = 1이 유일하게
   의미 있는 값이다.

6. **TECS-L 상수 체계와의 직접적 연결은 발견되지 않았다.** c^(1/6), c^(1/12),
   c^(1/17) 등은 "깨끗한" 값을 주지 않는다. 이는 c가 이미 플랑크 단위에서 1이므로
   추가적인 수론적 구조를 기대하기 어렵기 때문이다.

## Limitations

1. **c = lp/tp = 1은 동어반복이다.** 플랑크 단위는 c = 1이 되도록 설계되었다.
   이것을 "시뮬레이터의 클럭 속도"로 해석하는 것은 물리적 직관이지 증명이 아니다.

2. **격자 모델에는 로렌츠 불변성 문제가 있다.** 실제 격자(cubic lattice)는
   회전 불변성을 깨뜨린다. 디지털 물리학의 근본적 난제이다. 연속 대칭이 어떻게
   이산 격자에서 출현하는지는 미해결 문제이다.

3. **Bremermann/Lloyd 한계는 양자역학적 한계이다.** 만약 시뮬레이터가 양자역학
   바깥에 있다면 이 한계가 적용되지 않을 수 있다.

4. **시뮬레이션 가설은 반증 불가능하다.** "시뮬레이터가 존재한다"는 주장은
   실험적으로 검증할 방법이 없으며, 과학적 가설의 기준을 충족하지 못할 수 있다.

5. **Golden Zone 의존 없음.** 이 가설은 Golden Zone에 의존하지 않지만,
   TECS-L 상수 체계와의 새로운 연결도 발견하지 못했다.

## Verification Direction

1. 격자 모델에서 로렌츠 대칭이 자발적으로 출현할 수 있는 조건 조사
   (Causal Set Theory, CDT 등과의 연결)
2. 10^123 갭의 의미 심화: 우주상수 Lambda와의 관련성 (Lambda ~ 1/R^2 ~ 10^-123 in Planck units)
3. 홀로그래피 원리와 TECS-L의 차원 축소 연결 탐색
4. 시간 지연 = 계산 예산 재배분 해석을 구체적 셀룰러 오토마타로 구현

## Verdict

```
  Grade: 🟧 (Known physics reframed, no new TECS-L connections)

  c = lp/tp = 1 is a well-known tautology of Planck units (Planck 1899).
  The BFS/grid interpretation is valid but not new (Zuse 1969, Fredkin 1990).
  Time dilation as computation budget reallocation is an elegant framing.
  Grid ops >> Bremermann is a meaningful constraint pointing to holography.

  Key finding: Grid/Bremermann gap = 10^123 = Bekenstein bound.
  This connects computational capacity to holographic information theory.

  No new TECS-L constant system connections found for c.
  c^(1/n) for n = {6, 12, 17, 204} yields no nice numbers.
  This is expected: c = 1 in natural units has no further structure.
```

---
Verification script: `scripts/verify_hsim4.py`
