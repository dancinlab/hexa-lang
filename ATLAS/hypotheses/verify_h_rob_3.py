#!/usr/bin/env python3
"""H-ROB-3: Golden Zone = Stable Walking Region
Linear Inverted Pendulum Model (LIPM) verification.
Computes stability margins, Froude numbers across walking speeds.
"""
import math

g = 9.81  # gravity
foot_length = 0.26  # average foot length (m)
leg_length = 0.85   # average leg length (m), CoM height proxy
h_com = 0.85        # CoM height for LIPM

print("=" * 70)
print("H-ROB-3: Golden Zone = Stable Walking Region (LIPM Analysis)")
print("=" * 70)

# Golden Zone bounds
GZ_LOWER = 0.5 - math.log(4/3)  # 0.2123
GZ_UPPER = 0.5
GZ_CENTER = 1/math.e  # 0.3679

print(f"\nGolden Zone: [{GZ_LOWER:.4f}, {GZ_UPPER:.4f}], center={GZ_CENTER:.4f}")
print(f"Parameters: g={g}, foot_length={foot_length}m, leg_length={leg_length}m")

# --- Section 1: LIPM Stability Analysis ---
# LIPM: x(t) = x0*cosh(wt) + (v0/w)*sinh(wt)
# where w = sqrt(g/h)
# Stability requires ZMP to stay within support polygon

w = math.sqrt(g / h_com)  # natural frequency
T_c = 1.0 / w  # characteristic time

print(f"\nLIPM natural frequency w = sqrt(g/h) = {w:.4f} rad/s")
print(f"Characteristic time T_c = 1/w = {T_c:.4f} s")

# --- Section 2: Speed scan ---
print("\n" + "=" * 70)
print("Speed Scan: Stability Margin & Froude Number")
print("=" * 70)

speeds = [v/10 for v in range(1, 21)]  # 0.1 to 2.0 m/s

results = []
for v in speeds:
    # Optimal step length from LIPM: L_opt = v * T_step
    # For natural walk: T_step ~ 2*pi/(2*w) ~ pi/w (half period approximation)
    # More accurately: step time from preferred frequency
    # Preferred step frequency ~ 2 Hz at natural speed, scales with sqrt(v)

    # Step length from empirical relation: L = 0.42 * height * (v/v_natural)^0.42
    # Simplified: L ~ k * v^0.5 for walk, constrained by leg length
    # Using Grieve & Gear relation: step_length ≈ 1.346 * sqrt(v * leg_length / g) * leg_length
    # Froude-based: L/leg_length = a * Fr^b

    Fr = v**2 / (g * leg_length)  # Froude number

    # Step length from dimensional analysis + empirical data
    # At Fr~0.25 (natural walk), L/leg ≈ 0.75
    step_length = leg_length * 0.75 * math.sqrt(Fr / 0.25) if Fr < 0.5 else leg_length * 0.9
    step_length = min(step_length, leg_length * 1.0)  # can't exceed leg length

    step_time = step_length / v if v > 0 else 1.0

    # ZMP stability margin in LIPM:
    # During single support, ZMP moves from heel to toe
    # Normalized margin = how far ZMP stays from foot edge / foot_length
    # In LIPM: max ZMP excursion = (v^2)/(g*h) * foot_length_fraction

    # ZMP excursion from CoM dynamics:
    # x_zmp = x_com - (h/g) * x_ddot_com
    # For LIPM: x_zmp = constant (by definition)
    # But for real walking: ZMP trajectory moves ~60-80% of foot length

    # Stability margin = distance of ZMP from nearest foot edge / foot_length
    # At natural walk: ZMP traverses ~65% of foot, margin ~17.5% on each side
    # Normalized: min_margin / foot_length

    # Model: ZMP excursion fraction increases with speed
    zmp_excursion = 0.5 + 0.3 * (Fr / 0.5)  # fraction of foot used
    zmp_excursion = min(zmp_excursion, 0.95)

    # Stability margin = (1 - zmp_excursion) / 2  (symmetric)
    # But also consider dynamic balance: capture point must be in next step

    # Capture point: x_cp = x_com + v_com / w
    # Stability requires: capture point within reachable step
    capture_point_offset = v / w
    max_step = leg_length * 0.9  # max step limited by geometry

    # Dynamic stability margin: how much of max_step is used by capture point
    dynamic_margin = 1.0 - (capture_point_offset / max_step)
    dynamic_margin = max(0, min(1, dynamic_margin))

    # Combined stability metric:
    # Ratio of actual stability resource used vs available
    # Normalized to [0, 1]
    stability_margin = dynamic_margin * (1 - zmp_excursion/2)

    results.append({
        'v': v, 'Fr': Fr, 'step_length': step_length,
        'step_time': step_time, 'stability_margin': stability_margin,
        'dynamic_margin': dynamic_margin, 'capture_offset': capture_point_offset
    })

# Print table
print(f"\n{'Speed':>6} {'Fr':>7} {'StepL':>7} {'StepT':>7} {'CapOff':>7} {'DynMarg':>8} {'StabMarg':>9} {'Zone':>8}")
print("-" * 70)
for r in results:
    zone = ""
    if GZ_LOWER <= r['Fr'] <= GZ_UPPER:
        zone = "GZ-Fr"
    if GZ_LOWER <= r['stability_margin'] <= GZ_UPPER:
        zone += " GZ-SM"
    print(f"{r['v']:6.1f} {r['Fr']:7.4f} {r['step_length']:7.3f} {r['step_time']:7.3f} "
          f"{r['capture_offset']:7.3f} {r['dynamic_margin']:8.4f} {r['stability_margin']:9.4f} {zone:>8}")

# --- Section 3: Key Points ---
print("\n" + "=" * 70)
print("Key Biomechanical Constants vs Golden Zone")
print("=" * 70)

natural_speed = 1.2  # m/s
Fr_natural = natural_speed**2 / (g * leg_length)
Fr_transition = 0.5  # walk-to-run transition

# Preferred walk speed range
Fr_preferred_low = 0.8**2 / (g * leg_length)   # slow comfortable
Fr_preferred_high = 1.6**2 / (g * leg_length)   # fast walk

print(f"\nFroude number at natural walk speed (1.2 m/s): Fr = {Fr_natural:.4f}")
print(f"  Golden Zone lower bound:                      {GZ_LOWER:.4f}")
print(f"  Difference: {abs(Fr_natural - GZ_LOWER):.4f} ({abs(Fr_natural - GZ_LOWER)/GZ_LOWER*100:.1f}%)")
print(f"  MATCH: Fr_natural ~ GZ_lower? {'YES' if abs(Fr_natural - GZ_LOWER) < 0.05 else 'CLOSE' if abs(Fr_natural - GZ_LOWER) < 0.1 else 'NO'}")

print(f"\nFroude number at walk-to-run transition:        Fr = {Fr_transition:.4f}")
print(f"  Golden Zone upper bound:                      {GZ_UPPER:.4f}")
print(f"  Difference: {abs(Fr_transition - GZ_UPPER):.4f} ({abs(Fr_transition - GZ_UPPER)/GZ_UPPER*100:.1f}%)")
print(f"  MATCH: Fr_transition = GZ_upper? {'EXACT' if abs(Fr_transition - GZ_UPPER) < 0.001 else 'YES' if abs(Fr_transition - GZ_UPPER) < 0.01 else 'NO'}")

# Duty factor (fraction of gait cycle with foot on ground)
# Walk: duty > 0.5, Run: duty < 0.5
# At natural walk: duty ≈ 0.6-0.65
duty_natural = 0.62
print(f"\nDuty factor at natural walk: {duty_natural}")
print(f"  1 - duty = {1 - duty_natural:.2f} (flight phase fraction)")
print(f"  GZ center (1/e): {GZ_CENTER:.4f}")
print(f"  1 - duty ~ GZ center? {abs(1 - duty_natural - GZ_CENTER) < 0.05}")

# Relative stride length
rel_stride_natural = 2 * 0.75  # ~1.5 * leg_length for stride (2 steps)
rel_step_natural = 0.75
print(f"\nRelative step length (step/leg): {rel_step_natural:.3f}")
print(f"  This is between 2*GZ_lower and 2*GZ_upper:")
print(f"  [{2*GZ_LOWER:.3f}, {2*GZ_UPPER:.3f}] = [{2*GZ_LOWER:.3f}, {2*GZ_UPPER:.3f}]")

# --- Section 4: Pendulum energy exchange ---
print("\n" + "=" * 70)
print("Energy Recovery in Walking (Inverted Pendulum)")
print("=" * 70)

# Walking recovers kinetic<->potential energy
# Recovery rate R = 1 - W_ext / (delta_KE + delta_PE)
# At optimal speed: R ~ 65% (Cavagna et al.)
# R decreases at very slow/fast speeds

print("\nEnergy recovery rate vs speed:")
print(f"{'Speed':>6} {'Fr':>7} {'Recovery':>9} {'1-Recov':>9} {'Zone':>8}")
print("-" * 50)
for v_i in [0.5, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0]:
    Fr_i = v_i**2 / (g * leg_length)
    # Empirical recovery: peaks ~65% at ~1.2 m/s, Gaussian-like
    R_i = 0.65 * math.exp(-((v_i - 1.2)/0.6)**2)
    one_minus_R = 1 - R_i
    zone = ""
    if GZ_LOWER <= one_minus_R <= GZ_UPPER:
        zone = "GZ"
    if GZ_LOWER <= Fr_i <= GZ_UPPER:
        zone += " Fr-GZ"
    print(f"{v_i:6.1f} {Fr_i:7.4f} {R_i:9.4f} {one_minus_R:9.4f} {zone:>8}")

print(f"\nAt natural speed (1.2 m/s):")
R_opt = 0.65
print(f"  Recovery = {R_opt:.2f}")
print(f"  1 - Recovery = {1-R_opt:.2f} (energy that must be actively supplied)")
print(f"  GZ center (1/e) = {GZ_CENTER:.4f}")
print(f"  1-R ~ GZ center? {abs(1-R_opt - GZ_CENTER) < 0.05}")

# --- Section 5: ASCII Graph ---
print("\n" + "=" * 70)
print("ASCII Graph: Froude Number vs Speed + Golden Zone")
print("=" * 70)

# Plot Fr vs speed
max_Fr = 0.6
rows = 20
cols = 40

grid = [[' ' for _ in range(cols)] for _ in range(rows)]

# Mark Golden Zone
gz_low_row = rows - 1 - int(GZ_LOWER / max_Fr * (rows - 1))
gz_high_row = rows - 1 - int(GZ_UPPER / max_Fr * (rows - 1))
gz_center_row = rows - 1 - int(GZ_CENTER / max_Fr * (rows - 1))

for c in range(cols):
    if gz_high_row <= rows - 1:
        for r in range(max(0, gz_high_row), min(rows, gz_low_row + 1)):
            grid[r][c] = '.'

# Plot Fr curve
for i, v in enumerate([0.1 + 1.9 * x / (cols - 1) for x in range(cols)]):
    Fr_v = v**2 / (g * leg_length)
    row = rows - 1 - int(Fr_v / max_Fr * (rows - 1))
    row = max(0, min(rows - 1, row))
    col = i
    if col < cols:
        grid[row][col] = '*'

# Mark natural walk speed column
nat_col = int((1.2 - 0.1) / 1.9 * (cols - 1))
for r in range(rows):
    if grid[r][nat_col] == ' ':
        grid[r][nat_col] = '|'
    elif grid[r][nat_col] == '.':
        grid[r][nat_col] = ':'

print(f"\n  Fr")
print(f"  {max_Fr:.1f} |", end="")
for c in range(cols):
    print(grid[0][c], end="")
print()
for r in range(1, rows):
    fr_val = max_Fr * (rows - 1 - r) / (rows - 1)
    if r == gz_high_row:
        print(f"  {fr_val:.2f}|", end="")
    elif r == gz_low_row:
        print(f"  {fr_val:.2f}|", end="")
    elif r == gz_center_row:
        print(f"  {fr_val:.2f}|", end="")
    else:
        print(f"      |", end="")
    for c in range(cols):
        print(grid[r][c], end="")
    print()
print(f"  0.0 +{''.join(['-' for _ in range(cols)])}")
print(f"       0.1{''.join([' ' for _ in range(cols - 10)])}2.0  speed (m/s)")
print(f"             | = natural walk (1.2 m/s)")
print(f"             . = Golden Zone [{GZ_LOWER:.3f}, {GZ_UPPER:.3f}]")

# --- Section 6: Walk-to-Run Transition ---
print("\n" + "=" * 70)
print("Walk-to-Run Transition Analysis")
print("=" * 70)

# Walk-to-run transition speed
v_transition = math.sqrt(0.5 * g * leg_length)
print(f"\nWalk-to-run transition:")
print(f"  Fr = 0.5 at v = sqrt(0.5 * g * L) = {v_transition:.3f} m/s")
print(f"  Fr = 0.5 = GZ_upper = 1/2 (Riemann critical line)")
print(f"  This is EXACT (by definition Fr_crit = 0.5, GZ_upper = 1/2)")
print(f"")
print(f"  Minimum cost of transport (natural walk):")
print(f"  Fr ~ 0.25 at v ~ {math.sqrt(0.25 * g * leg_length):.3f} m/s")
print(f"  Fr_natural = {Fr_natural:.4f}")
print(f"  GZ_lower = {GZ_LOWER:.4f}")
print(f"  Difference = {abs(Fr_natural - GZ_LOWER):.4f}")

# --- Section 7: Stability margin ASCII graph ---
print("\n" + "=" * 70)
print("ASCII Graph: Stability Margin vs Speed")
print("=" * 70)

max_sm = 1.0
rows2 = 15
cols2 = 40

grid2 = [[' ' for _ in range(cols2)] for _ in range(rows2)]

# Mark Golden Zone
gz_low_row2 = rows2 - 1 - int(GZ_LOWER / max_sm * (rows2 - 1))
gz_high_row2 = rows2 - 1 - int(GZ_UPPER / max_sm * (rows2 - 1))

for c in range(cols2):
    for r in range(max(0, gz_high_row2), min(rows2, gz_low_row2 + 1)):
        grid2[r][c] = '.'

# Plot stability margin
for i in range(cols2):
    v_i = 0.1 + 1.9 * i / (cols2 - 1)
    # Find matching result
    best_r = min(results, key=lambda r: abs(r['v'] - v_i))
    sm = best_r['stability_margin']
    row = rows2 - 1 - int(sm / max_sm * (rows2 - 1))
    row = max(0, min(rows2 - 1, row))
    if grid2[row][i] in (' ', '.'):
        grid2[row][i] = '*'

print(f"\n  SM")
print(f"  1.0 |", end="")
for c in range(cols2):
    print(grid2[0][c], end="")
print()
for r in range(1, rows2):
    sm_val = max_sm * (rows2 - 1 - r) / (rows2 - 1)
    if r == gz_high_row2:
        print(f"  {sm_val:.2f}|", end="")
    elif r == gz_low_row2:
        print(f"  {sm_val:.2f}|", end="")
    else:
        print(f"      |", end="")
    for c in range(cols2):
        print(grid2[r][c], end="")
    print()
print(f"  0.0 +{''.join(['-' for _ in range(cols2)])}")
print(f"       0.1                                2.0  speed (m/s)")
print(f"       . = Golden Zone")

# --- Section 8: Summary ---
print("\n" + "=" * 70)
print("SUMMARY")
print("=" * 70)
print(f"""
  Key Finding 1: Walk-to-run transition at Fr = 0.5 = GZ_upper (EXACT)
    - This is definitional: Fr_crit = 0.5, GZ_upper = 1/2
    - But: the PHYSICAL meaning is that gait transition = zone boundary

  Key Finding 2: Natural walk Fr ~ 0.17-0.21
    - Fr at 1.2 m/s = {Fr_natural:.4f}
    - GZ_lower = {GZ_LOWER:.4f}
    - Close but not exact match (off by ~{abs(Fr_natural - GZ_LOWER)/GZ_LOWER*100:.0f}%)

  Key Finding 3: Walking AS Golden Zone phenomenon
    - Stable walking exists in Fr range [~0.05, 0.5]
    - Preferred/efficient walking in Fr range [~0.15, 0.35]
    - Golden Zone [0.212, 0.500] overlaps significantly

  Key Finding 4: Energy recovery 1-R ~ 0.35 ~ 1/e at optimal speed
    - Passive recovery = 65%, active input = 35%
    - 0.35 vs 1/e = {GZ_CENTER:.4f} (diff = {abs(0.35 - GZ_CENTER):.4f})

  Honest Assessment:
    - Fr_transition = 0.5 = GZ_upper is exact but partly definitional
    - Fr_natural ~ GZ_lower is approximate (within ~20%)
    - Energy recovery match is suggestive but empirical data varies
    - Overall: moderate support for Golden Zone mapping
""")
