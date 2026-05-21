# Conventional h-phi formulation for stacked pancakes

This folder contains the GetDP implementation of the **conventional h-phi formulation** for stacked pancakes.  

*Reference: J. Dular et al., IEEE Transactions on Applied Superconductivity, 2020.*

---

## Contents

- **`pancakes_ref.pro`**  
  Generic GetDP model file.

- **`pancakes_ref_5.100.msh`**  
  Example 2D mesh of a stacked pancake coil generated with Gmsh 4.14.0.  
  All 100 tapes per stack are discretized.

---

## Usage

1.  Potential mesh partitioning if used with MPI (8 Ranks) GetDP:  
    ```bash
    gmsh pancakes_ref_5.100.msh -part 8 -o pancakes_ref_5.100_part8.msh -
    ```

2.  Running the simulation without MPI and post-processing losses:
    ```bash
    getdp pancakes_ref.pro -solve MagDyn -bin -cpu -msh pancakes_ref_5.100.msh -v 3
    getdp pancakes_ref.pro -pos detailedPower -bin -msh pancakes_ref_5.100.msh -v 3
    ```

3.  Alternatively, running simulation with MPI (8 tasks):
    ```bash
    mpirun -np 8 getdp pancakes_ref.pro -solve MagDyn -bin -cpu -msh pancakes_ref_5.100_part8.msh -v 3 -sparsity
    getdp pancakes_ref.pro -pos detailedPower -bin -msh pancakes_ref_5.100_part8.msh -v 3 -sparsity
    ```
