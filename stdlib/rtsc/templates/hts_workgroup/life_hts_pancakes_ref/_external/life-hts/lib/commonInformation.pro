// ---- Formulation definitions (dummy values) ----
DefineConstant [formulation];
h_formulation = 2;
a_formulation = 6;
coupled_formulation = 5;
ha_formulation = 5; // idem as "coupled-"
ta_formulation = 7;
automatic_ha_domains = 1; // If put to 0 -> define domains yourself
a_enrichment = 1; // If put to 1 -> a-space is enriched for h-a-formulation. Put to 0 -> h-space
alt_formulation = 0; // Mixed variation for better handing the nonlinear laws
h_phi_ts_formulation = 8; // Shell model in the H-phi formulation

// ---- Default flags (to be modified in relevant .pro files if necessary) ----
Flag_CTI = 0; // Are there time instants where we want to exactly stop?

Flag_MB = 0; // Is there a moving band in the model, with special boundary conditions?
Flag_rotating = 0; // Is the rotor rotating? (position to be updated during the resolution)
Flag_Hysteresis = 0; // Hysteresis model for ferro? (how to handle it is not yet implemented!)
Flag_hs = 0; // Source field in stranded region?
Flag_spurious_conductivity = 0; // Conductivity in air? (do not use!)
Flag_save_hs = 0; // Save the obtained source field (for debugging only: risk of conflict with other resolutions)
Flag_jcb = 0; // b dependence in critical current density?
Flag_nb = 0; // b dependence in power exponent?
Flag_twist = 0;
Nb_source_domain = 0;
Flag_cohomology = 0; // Cuts are handled with cohomology solver in Gmsh ? (TBC...)
Axisymmetry = 0; // Not axi by default
Flag_NormalSign = 1; // Normal sign in the geometry (put to -1) if coupling leads to opposite results in one region
k_max = 1; // For helicoidal problems
Homogenized = 0; // For homogenized stack of tapes

realTimeInfo = 0; // Output some information in Onelab during resolution? (requires an "Info" post-operation)
realTimeSolution = 0; // Output the fields in Onelab during resolution? (not recommended because slower)

N_ele = 1; // Default number of layers for the thin-shell formulation
// Linearization: do we use Newton-Raphson (N-R) in h-formulation and a-formulation for ...
Flag_LinearProblem = 0;
// (for other formulations, no choice is possible)
Flag_h_NR_Mu = 1; // ... the permeability? (with 1, hybrid method, starting with a number of Picard iterations)
Flag_h_NR_Rho = 1; // ... the resistivity?
Flag_a_NR_Nu = 1; // ... the reluctivity?
Flag_a_NR_Sigma = 0; // ... the conductivity? (no by default because cycles)
// Use relaxation factors?
tryrelaxationfactors = 0;
relaxation_factor = 1.0; // Relaxation factor for the nonlinear iterations (1.0 = no relaxation)
// Use variable maximum time step?
Flag_variable_dt_max = 0;

Flag_compute_voltage_h_phi = 1; // Compute the voltage in the h-phi formulation? Can be changed to zero if strong constraint on applied current
Flag_try_ASM_before_MUMPS = 0; // Try GMRES-ASM-MUMPS for the linear solver? (if not, MUMPS is used directly). FOR NOW, THIS IS ONLY ACTIVATED in simple_resolution.pro

// Convergence criterion
// 0: energy estimate
// 1: absolute/relative residual (do not use)
// 2: relative increment (do not use either)
convergenceCriterion = 0;
tol_abs = 1e-10; //Absolute tolerance on nonlinear residual
tol_rel = 1e-6; // Relative tolerance on nonlinear residual
tol_incr = 5e-3; // Relative tolerance on the solution increment

// Useful for convergence criterion
IsThereFerro = 0; // Put to 1 in the .pro if there is a nonlinear ferro
IsThereSuper = 0; // Put to 1 in the .pro if there is a nonlinear conducting domain

// Output information
DefineConstant [economPos = 0]; // 0: Saves all fields. 1: Does not save fields (.pos)
DefineConstant [economInfo = 0]; // 0: Saves all iteration/residual info. 1: Does not save them
// Parameters
saveAll = 0;  // Save all the iterations? (pay attention to memory! heavy files)
saveAllSteps = 0;
saveAllStepsSeparately = 0;

Group{
    // Regions that must be consistently completed (or left empty if they do not apply)
    DefineGroup[OmegaC, OmegaC_stranded, BndOmegaC_stranded, OmegaCC, Omega, BndOmegaC, Omega_noStranded];
    DefineGroup[Gamma_e, Gamma_h, GammaAll];
    DefineGroup[MagnLinDomain, MagnAnhyDomain, MagnHystDomain]; // Union is Omega (to specify in .pro)
    DefineGroup[LinOmegaC, NonLinOmegaC]; // Union is OmegaC (to specify in .pro)

    DefineGroup[Cuts, Cuts_stranded, BndOmegaC_side, BndOmegaC_stranded_side]; // For the h-formulation (BndOmegaC_side is on one side of the cut)
    DefineGroup[Electrodes]; // For the a-formulation in 3D
    DefineGroup[LateralEdges, PositiveEdges]; // For the t-a-formulation (point in 2D, line in 3D)
    DefineGroup[GammaS, GammaS_1, GammaS_0]; // For thin-shell model

    // Group Names for which constitutive laws will automatically be attributed
    DefineGroup [Air, Copper, Super, Ferro];

}

Function{
    // Functions that will be called in some post-operation (define them or not)
    DefineFunction [I, js, hsVal, directionApplied, thickness];
}
