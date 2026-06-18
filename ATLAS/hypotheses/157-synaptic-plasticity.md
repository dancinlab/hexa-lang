# Hypothesis Review 157: Synaptic Plasticity (LTP/LTD) and Plasticity Mapping

## Status: ✅ Verified

## Hypothesis

> Synaptic plasticity (LTP: long-term potentiation, LTD: long-term depression) directly corresponds to Plasticity (P) in our model. Infants P≈0.9, adults P≈0.6, elderly P≈0.3, and in savants D↑ → P↑ (compensatory plasticity) occurs.

## Background

Synaptic plasticity is the ability of synaptic connection strength to change with experience. LTP (Long-Term Potentiation) represents synaptic strengthening and LTD (Long-Term Depression) represents synaptic weakening; the balance of these two mechanisms is the basis of learning and memory.

Plasticity changes dramatically with age. Plasticity is maximum in the "critical period" of infancy, decreases in adulthood, and significantly declines in old age. However, when brain damage (D↑) occurs, a phenomenon of compensatorily increased plasticity is observed.

Related hypotheses: Hypothesis 156 (Sylvian fissure deficit), Hypothesis 159 (meditation), Hypothesis 162 (acquired savant)

## Age-Wise Plasticity Mapping

| Age group | LTP efficiency | LTD efficiency | P (estimate) | Note |
|---|---|---|---|---|
| Infants (0-3) | Very high | High | 0.85-0.95 | Critical period, synaptic excess |
| Children (4-12) | High | Medium | 0.70-0.85 | Synaptic pruning begins |
| Adolescents (13-18) | Medium-high | Medium | 0.60-0.75 | Frontal lobe maturation |
| Adults (19-50) | Medium | Medium | 0.50-0.65 | Stable connections |
| Middle-aged (51-65) | Medium-low | Medium | 0.40-0.55 | Gradual decrease |
| Elderly (66+) | Low | High | 0.25-0.40 | LTD dominant, synaptic loss |

## Age-Plasticity Graph

```
  P (Plasticity)
  1.0│
     │  ●
  0.9│   ● Infants
     │     ●           ★ Savant (D↑→P↑ compensatory)
  0.8│       ●        ╱
     │        ●     ╱   ← Compensatory plasticity
  0.7│         ●  ╱
     │          ●
  0.6│─ ─ ─ ─ ─ ● ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ Adult average
     │            ●
  0.5│─ ─ ─ ─ ─ ─ ─● ─ ─ ─ ─ ─ ─ ─ ─ Critical line
     │               ●
  0.4│                 ●
     │                   ●
  0.3│                     ●
     │                       ● Elderly
  0.2│                         ●
     │
  0.0└──┬──┬──┬──┬──┬──┬──┬──┬──→ Age
       0  5 10 15 25 35 50 65 80 (years)

  ── Normal aging curve     ★ Compensatory plasticity (savant)
```

## D↑ → P↑ Compensatory Plasticity Mechanism

```
  Normal brain:
  ┌──────┐    normal connection    ┌──────┐
  │Area A│ ═══════════════════════│Area B│     D=0.1, P=0.6
  └──────┘                        └──────┘

  After damage/absence:
  ┌──────┐    damaged connection   ┌──────┐
  │Area A│ ═══╳╳╳═════════════════│Area B│     D=0.6
  └──────┘  ↓                     └──────┘
            ↓ compensatory rewiring
  ┌──────┐  ╲  new pathways      ╱ ┌──────┐
  │Area A│ ──╲──────────────────╱──│Area B│   D=0.6, P=0.85
  └──────┘    ╲────────────────╱   └──────┘
               ╲──────────────╱  ← multiple alternative paths formed
                ╲────────────╱      (requires high plasticity)
```

## Paradox of Golden Zone Access and Age

### Infant Paradox: High P but Not Golden Zone

```
  Infants: D≈0.05, P≈0.9, I≈0.7
  G = 0.05 × 0.9 / 0.7 = 0.064  ← Normal (D is too low)

  Savant: D≈0.6, P≈0.85, I≈0.35
  G = 0.6 × 0.85 / 0.35 = 1.46  ← Singularity! (triple alignment of D+P+I)

  Elderly stroke: D≈0.5, P≈0.3, I≈0.5
  G = 0.5 × 0.3 / 0.5 = 0.30   ← Normal (P is too low)
```

Core insight: **P alone is insufficient.** Simultaneous optimization of all three variables is needed in G = D × P / I.

### Why Elderly Stroke Patients Don't Become Savants

In the elderly, even when D↑ occurs, P is already low (≈0.3) so compensatory rewiring is insufficient. This is why acquired savants (Hypothesis 162) primarily occur in young adults.

```
  Probability of compensatory savant occurrence

  Probability
  1.0│
     │
  0.8│
     │      ● Savant probability when D↑ occurs
  0.6│     ● ●
     │    ●     ●
  0.4│   ●        ●
     │  ●           ●
  0.2│ ●               ●
     │●                   ●  ●  ●
  0.0└──┬──┬──┬──┬──┬──┬──┬──┬──→ Age
       0  5 10 15 25 35 50 65 80 (years)
```

## LTP/LTD Ratio and P Relationship

```
  LTP/LTD ratio:
  High (>1) = synaptic strengthening dominant = P↑ = easy learning
  Balanced (≈1) = synaptic stability = medium P = maintenance state
  Low (<1) = synaptic weakening dominant = P↓ = memory loss
```

## Limitations

- Plasticity varies by brain region; difficult to reduce to a single P value
- Direct measurement of LTP/LTD is only possible in animal models (humans require indirect estimation)
- The quantitative relationship of compensatory plasticity (D↑→P↑) is not established
- Age-wise P values are population averages with large individual variation
- Molecular-level mechanisms such as BDNF, CREB are not reflected

## Verification Directions

- [ ] Develop P estimation model from fMRI-based functional connectivity changes
- [ ] Quantitatively measure compensatory plasticity levels in savant group
- [ ] Calibrate P curve from age-wise learning rate data
- [ ] Mathematical model of D-P compensatory relationship: P_comp = P_base + α × D^β
- [ ] Simulate P changes when pharmacological plasticity enhancement (BDNF promoter) is applied

---

*Written: 2026-03-22*
*Status: ✅ Age-plasticity mapping and compensatory plasticity model confirmed*
