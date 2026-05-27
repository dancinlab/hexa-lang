# Simultaneous multi-scale h-phi thin-shell formulation for stacked pancakes

This folder contains the GetDP implementation of the **simultaneous multi-scale h-phi thin-shell formulation** for stacked pancakes.  

*References:*  
- E. Berrospe et al., *Superconductor Science and Technology*, 2021 (simultaneous multi-scale method)  
- B. de Sousa Alves et al., *Superconductor Science and Technology*, 2021 (h-phi thin-shell formulation)  
- L. Denis et al., in press, 2025 (combination of both)


---

## Contents

- **`pancakes_smsts.pro`**  
  Generic GetDP model file.

- **`pancakes_smsts_5.100.7.single.msh`**  
  Example 2D mesh of a stacked pancake coil generated with Gmsh 4.14.0.  
  7 analyzed tapes: 1, 25, 66, 88, 96, 99.
  Single element layer in each bulk between analyzed tapes.

- **`pancakes_smsts_5.100.7.noSingle.msh`**  
  Example 2D mesh of a stacked pancake coil generated with Gmsh 4.14.0.  
  7 analyzed tapes: 1, 25, 66, 88, 96, 99.
  Multiple element layers (up to 3, depending on bulk thickness) in each bulk between analyzed tapes.

- **`pancakes_smsts_5.100_ref.msh`**  
  Example 2D mesh of a stacked pancake coil generated with Gmsh 4.14.0.  
  100 analyzed tapes: 1, 25, 66, 88, 96, 99.
  This is equivalent to the classical h-phi thin-shell formulation.
  Use `-setnumber num_analyzed_tapes 100` when running GetDP in the instructions below.

---

## Usage

1.  Potential mesh partitioning if used with MPI (8 Ranks) GetDP:  
    ```bash
    gmsh pancakes_smsts_5.100.7.single.msh -part 8 -o pancakes_smsts_5.100.7.single_part8.msh -
    ```

2.  Running the simulation without MPI and post-processing losses:
    ```bash
    getdp pancakes_smsts.pro -solve MagDyn -bin -cpu -msh pancakes_smsts_5.100.7.single.msh -v 3
    getdp pancakes_smsts.pro -pos detailedPower -bin -msh pancakes_smsts_5.100.7.single.msh -v 3
    ```

3.  Alternatively, running simulation with MPI (8 tasks):
    ```bash
    mpirun -np 8 getdp pancakes_smsts.pro -solve MagDyn -bin -cpu -msh pancakes_smsts_5.100.7.single_part8.msh -v 3 -sparsity
    getdp pancakes_smsts.pro -pos detailedPower -bin -msh pancakes_smsts_5.100.7.single_part8.msh -v 3 -sparsity
    ```

4.  Note that the GetDP resolution automatically computes the losses based on the PCHIP interpolation.

    *Reference:*  
    - E. Berrospe et al., *Superconductor Science and Technology*, 2021.

    This is done by automatic call of Python script **`loss_interpolation.py`** during resolution.
