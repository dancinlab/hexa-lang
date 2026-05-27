# h-phi foil winding formulation for stacked pancakes

This folder contains the GetDP implementation of the **h-phi foil winding formulation** for stacked pancakes.  

*Reference: L. Denis et al., IEEE Transactions on Magnetics, 2025.*

---

## Contents

- **`pancakes_fw.pro`**  
  Generic GetDP model file.

- **`pancakes_fw_5.100.12.msh`**  
  Example 2D mesh of a stacked pancake coil generated with Gmsh 4.14.0.  
  12 layers of elements along vertical axis for each pancake.

---

## Usage

1.  Potential mesh partitioning if used with MPI (8 Ranks) GetDP:  
    ```bash
    gmsh pancakes_fw_5.100.12.msh -part 8 -o pancakes_fw_5.100.12_part8.msh -
    ```

2.  Running the simulation without MPI and post-processing losses:
    ```bash
    getdp pancakes_fw.pro -solve MagDyn -bin -cpu -msh pancakes_fw_5.100.12.msh -v 3
    getdp pancakes_fw.pro -pos detailedPower -bin -msh pancakes_fw_5.100.12.msh -v 3
    ```

3.  Alternatively, running simulation with MPI (8 tasks):
    ```bash
    mpirun -np 8 getdp pancakes_fw.pro -solve MagDyn -bin -cpu -msh pancakes_fw_5.100.12_part8.msh -v 3 -sparsity
    getdp pancakes_fw.pro -pos detailedPower -bin -msh pancakes_fw_5.100.12_part8.msh -v 3 -sparsity
    ```
