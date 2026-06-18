# H-CX-152: PH = Rosch Prototype Theory — Dendrogram Matches Basic Level of Cognitive Categories
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


> Rosch(1975) basic-level category = middle depth of PH merge.
> Superordinate (animal) = root, basic (dog) = middle, subordinate (golden retriever) = leaf.

## Background

Eleanor Rosch's (1975, 1976) Prototype Theory proposed
three levels as the core structure of human categorization:

| Level | Example | Characteristics |
|------|------|------|
| Superordinate | animal, vehicle | abstract, few common features |
| Basic-level | dog, car | most natural category, optimal features |
| Subordinate | golden retriever, sedan | concrete, only experts distinguish |

Rosch's key findings:
1. Basic level is named fastest (minimum response time)
2. At the basic level, within-category similarity is maximized and between-category difference is maximized
3. Children learn the basic level first

In PH dendrogram:
- Latest merge = superordinate level (root: animal vs vehicle)
- Middle merge = basic level (individual class unit)
- Earliest merge = subordinate level (within-class variation)

This hypothesis claims that the merge depth structure of PH dendrogram
matches Rosch's three levels quantitatively.

## Predictions

```
PH dendrogram vs Rosch level correspondence:

merge    |
distance |
  1.0    |              ROOT (superordinate: animal/vehicle)
         |             /    \
  0.6    |     -------      -------      (basic level)
         |    / | \          / | \
  0.3    |  cat dog deer   car truck ship  (individual classes)
         |  /|  /|  /|    /|   /|   /|
  0.1    | .. .. ..  ..   .. ..  .. ..     (subordinate: variation)
         +---------------------------------->
              samples within classes
```

| Rosch Level | PH merge distance | Ratio (relative to total) |
|-----------|-------------------|----------------|
| Superordinate | 0.8-1.0 (maximum) | 80-100% |
| Basic | 0.4-0.6 (middle) | 40-60% |
| Subordinate | 0.1-0.3 (minimum) | 10-30% |

Key predictions:
1. 3 modes exist in merge distance distribution (corresponding to three levels)
2. Basic level merges are most frequent (peak)
3. CIFAR-10's 10 classes are positioned at the basic level
4. animal/vehicle separation is positioned at the superordinate level

## Verification Methods

1. Extract CIFAR-10 features from PureField model
2. Perform hierarchical clustering (Ward method)
3. Analyze merge distance distribution of dendrogram
4. Confirm 3-mode distribution (Gaussian mixture model, k=3)
5. Confirm correspondence of each mode to Rosch level

**Literature comparison:**
- Rosch(1975) "Cognitive representations of semantic categories" — reaction time data
- Murphy & Brownell(1985) "Category differentiation in object recognition"
- Compare basic-level categories from these papers with middle merge level of PH dendrogram

**Quantitative indicators:**
- silhouette score at each level
- Correlation between Rosch's "cue validity" calculation and PH merge distance

## Related Hypotheses

- **H-CX-85**: PH dendrogram and consciousness structure
- **H-CX-143**: THC dendrogram restructuring (Rosch structure collapse?)
- **H-CX-142**: THC PH simplification
- Cognitive science literature: Rosch(1975, 1976), Mervis & Rosch(1981)

## Limitations

1. CIFAR-10 with 10 classes cannot fully cover Rosch's three levels (subordinate level absent)
2. Rosch's theory is about natural categories and may not directly correspond to CIFAR-10 categories
3. Correspondence between PH dendrogram merge distance and cognitive "level" is an analogy
4. Results differ by hierarchical clustering method (Ward vs single vs complete)
5. Definition of "basic level" varies by culture and expertise

## Verification Status

- [ ] Generate PH dendrogram and analyze merge distance distribution
- [ ] Confirm 3-mode distribution
- [ ] Rosch literature comparison
- [ ] silhouette score comparison
- Currently: **unverified**
