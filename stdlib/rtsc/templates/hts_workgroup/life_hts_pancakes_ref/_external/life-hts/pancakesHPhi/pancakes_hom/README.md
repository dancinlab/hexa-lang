# h-phi Vanilla homogenization for stacked pancakes

This folder contains the GetDP implementation of the **h-phi Vanilla homogenization method** for stacked pancakes.  

*Adapted from V. Zermeno et al., Journal of Applied Physics, 2013.*

---

## Contents

- **`pancakes_hom.pro`**  
  Generic GetDP model file.

- **`pancakes_hom_5.100.12.1.msh`**  
  Example 2D mesh of a stacked pancake coil generated with Gmsh 4.14.0.  
  12 homogenized blocks along vertical axis for each pancake.
  1 element layer per block.

---

## Usage

1.  Potential mesh partitioning if used with MPI (8 Ranks) GetDP:  
    ```bash
    gmsh pancakes_hom_5.100.12.1.msh -part 8 -o pancakes_hom_5.100.12.1_part8.msh -
    ```

2.  Running the simulation without MPI and post-processing losses:
    ```bash
    getdp pancakes_hom.pro -solve MagDyn -bin -cpu -msh pancakes_hom_5.100.12.1.msh -v 3
    getdp pancakes_hom.pro -pos detailedPower -bin -msh pancakes_hom_5.100.12.1.msh -v 3
    ```

3.  Alternatively, running simulation with MPI (8 tasks):
    ```bash
    mpirun -np 8 getdp pancakes_hom.pro -solve MagDyn -bin -cpu -msh pancakes_hom_5.100.12.1_part8.msh -v 3 -sparsity
    getdp pancakes_hom.pro -pos detailedPower -bin -msh pancakes_hom_5.100.12.1_part8.msh -v 3 -sparsity
    ```
