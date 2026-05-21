# GetDP files for stacked pancakes of HTS tapes simulation (2D)

L. Denis, B. Vanderheyden and C. Geuzaine, 2025.  
Presented at EUCAS2025.  

This repository contains GetDP scripts for the simulation of stacked pancakes in 2D, corresponding to the research paper **Simultaneous Multi-Scale Homogeneous H-Phi Thin-Shell Model for Efficient Simulations of Stacked HTS Coils**, L. Denis, B. Vanderheyden, C. Geuzaine, submitted, Oct. 2025.

Most homogenization methods rely on the **h-phi FE formulation**, with the t-a SMSH method also implemented for comparison.

Benchmark problem geometry: 
- E. Berrospe et al., SUST, 2021.

All simulations were run with **GetDP 4.0.0** (commit a2503553f1e2713ffda7f22fc6d4d0e0c68ee0eb), compiled with PETSc 3.23.4 and MUMPS 5.7.3, with MPI support.

---

## Repository structure

This repository contains five model subfolders:

1. **`pancakes_ref/`**  
    Conventional h-phi formulation for stacked pancakes.  
    *Reference:*
    - J. Dular et al., IEEE TASC, 2020.

2. **`pancakes_hom/`**  
   Implementation of the h-phi Vanilla homogenization method for stacked pancakes.  
   *Adapted from:*
   - V. Zermeno et al., Journal of Applied Physics, 2013.

3. **`pancakes_fw/`**  
   Implementation of the h-phi foil winding formulation for stacked pancakes.  
   *Reference:* 
   - L. Denis et al., IEEE TMag, 2025.

4. **`pancakes_smsts/`**  
   Simultaneous multi-scale h-phi thin-shell formulation for stacked pancakes. This simplifies to the h-phi thin-shell formulation if all tapes are chosen to be analyzed. 
   *References:*  
   - E. Berrospe et al., SUST, 2021 (simultaneous multi-scale method)  
   - B. de Sousa Alves et al., SUST, 2021 (h-phi thin-shell formulation)  
   - L. Denis et al., in press, 2025 (original combination of both)

5. **`pancakes_smsts_ta/`**  
   Simultaneous multi-scale t-a formulation for stacked pancakes. This simplifies to the t-a formulation if all tapes are chosen to be analyzed. 
   *Reference:*  
   - E. Berrospe et al., SUST, 2021

As well as two shared subfolders:

1. **`common/`**  
   Constants, geometrical parameters and material functions shared between all models.

2. **`lib/`**  
   Resolution procedures, numerical integration and nomenclature shared between all models.

---

## Requirements

- [GetDP 4.0.0](https://getdp.info/)  
- [Gmsh 4.14.0](https://gmsh.info/) (for mesh generation)  
- Python ≥ 3.9 (for optional post-processing utilities)

---

## Usage

The usage of the different models is described in each subfolder.
