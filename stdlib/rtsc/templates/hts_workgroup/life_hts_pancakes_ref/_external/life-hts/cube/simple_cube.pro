Include "cube_data.pro";
Include "../lib/commonInformation.pro";

// This file defines a simplified (faster) version of the cube model.
// Same as in cube.pro, but with:
// built-in instead of user-defined material functions
// built-in resolution procedures (automatic adaptive time stepping and non-linear iterations)
// convergence based on residuals instead of energy estimates

// to run this file with MPI-compatible GetDP version (to be compiled locally beforehand) and 8 tasks:
// gmsh cube.geo -3
// gmsh cube.msh -part 8 -o cube_part8.msh -
// mpirun -np 8 getdp simple_cube.pro -solve MagDyn -msh cube_part8.msh -sparsity


Group {
    // ------- PROBLEM DEFINITION -------
    // Test name - for output files
    name = "cube";
    // (directory name for .txt files, not .pos files)
    testname = "simple_cube_model";
    // Dimension of the problem
    Dim = 3;
    // Axisymmetry of the problem
    Axisymmetry = 0; // Not axi

    // ------- WEAK FORMULATION -------
    // Choice of the formulation
    formulation = h_formulation; // only available choice

    Flag_compute_voltage_h_phi = 0; // current applied strongly, no voltage computation

    // ------- Definition of the physical regions -------
    // Material type of region MATERIAL, 0: air, 1: super, 2: copper
    MaterialType = 1;
    // Filling the regions
    Air = Region[ AIR ];
    If(MaterialType == 0)
        Air += Region[ MATERIAL ];
    ElseIf(MaterialType == 1)
        Super += Region[ MATERIAL ];
        BndOmegaC += Region[ BND_MATERIAL ];
        IsThereSuper = 1;
    ElseIf(MaterialType == 2)
        Copper += Region[ MATERIAL ];
        BndOmegaC += Region[ BND_MATERIAL ];
    EndIf

    // Fill the regions for formulation
    MagnAnhyDomain = Region[ {Ferro} ];
    MagnLinDomain = Region[ {Air, Super, Copper} ];
    NonLinOmegaC = Region[ {Super} ];
    LinOmegaC = Region[ {Copper} ];
    OmegaC = Region[ {LinOmegaC, NonLinOmegaC} ];
    OmegaCC = Region[ {Air, Ferro} ];
    Omega = Region[ {OmegaC, OmegaCC} ];

    // Boundaries for BC
    SurfOut = Region[ SURF_OUT ];
    SurfSym_bn0 = Region[ {SURF_SYM_MAT_bn0, SURF_SYM_bn0} ];
    SurfSym_ht0 = Region[ {SURF_SYM_MAT_ht0, SURF_SYM_ht0} ];
    Gamma_h = Region[{SurfOut, SurfSym_ht0}];
    Gamma_e = Region[{SurfSym_bn0}];
    GammaAll = Region[ {Gamma_h, Gamma_e} ];
}


Function{
    // ------- PARAMETERS -------
    // Superconductor parameters
    DefineConstant [jc = 1e8]; // Critical current density [A/m2]
    DefineConstant [n = 100]; // Superconductor exponent (n) value [-]

    // Excitation - Source field or imposed current intensty
    // 0: sine, 1: triangle, 2: up-down-pause, 3: step, 4: up-pause-down
    DefineConstant [Flag_Source = 0];
    DefineConstant [f = 50]; // Frequency of imposed current intensity [Hz]
    DefineConstant [bmax = 0.2]; // Maximum applied magnetic induction [T]
    DefineConstant [timeStart = 0]; // Initial time [s]
    DefineConstant [timeFinal = 1.25/f]; // Final time for source definition [s]
    DefineConstant [timeFinalSimu = timeFinal]; // Final time of simulation [s]

    // Numerical parameters
    DefineConstant [nbStepsPerPeriod = 200]; // Number of time steps over one period [-]
    DefineConstant [dt = 1/(nbStepsPerPeriod*f)]; // Time step (initial if adaptive)[s]
    DefineConstant [dt_max = dt]; // Maximum allowed time step [s]
    DefineConstant [iter_max = 100]; // Maximum number of nonlinear iterations
    DefineConstant [relaxation_factor = 1.0]; // Relaxation factor for the nonlinear iterations (1.0 = no relaxation)
    DefineConstant [tol_rel = 1e-8]; // Relative tolerance on nonlinear residual
    DefineConstant [tol_abs = 1e-12]; // Absolute tolerance on nonlinear residual
    // Control points
    controlPoint1 = {1e-5,0, 0}; // CP1
    controlPoint2 = {a/2-1e-5, 0, 0}; // CP2
    controlPoint3 = {0, a/2+2e-3, 0}; // CP3
    controlPoint4 = {a/2, a/2+2e-3, 0}; // CP4
    savedPoints = 2000; // Resolution of the line saving postprocessing

    Flag_try_ASM_before_MUMPS = 0; // Try GMRES-ASM-MUMPS for the linear solver? (if not, MUMPS is used directly).
}

Include "../lib/lawsAndFunctions.pro";

Function{
    // Direction of applied field
    directionApplied[] = Vector[0., 0., 1.]; // Only possible choice provided the symmetry of the geometry
    hmax = bmax / mu0;
    If(Flag_Source == 0)
        // Sine source field
        controlTimeInstants = {0., timeFinalSimu, 1/(2*f), 1/f, 3/(2*f), 2*timeFinal};
        hsVal[] = hmax * Sin[2.0 * Pi * f * $Time];
    ElseIf(Flag_Source == 1)
        // Triangle source field (5/4 of a complete cycle)
        controlTimeInstants = {0., timeFinal, timeFinal/5.0, 3.0*timeFinal/5.0, timeFinal};
        rate = hmax * 5.0 / timeFinal;
        hsVal[] = (($Time < timeFinal/5.0) ? $Time * rate :
                    ($Time >= timeFinal/5.0 && $Time < 3.0*timeFinal/5.0) ?
                    hmax - ($Time - timeFinal/5.0) * rate :
                    - hmax + ($Time - 3.0*timeFinal/5.0) * rate);
    ElseIf(Flag_Source == 4)
        // Up-pause-down
        controlTimeInstants = {0., timeFinal/3.0, 2.0*timeFinal/3.0, timeFinal};
        rate = hmax * 3.0 / timeFinal;
        hsVal[] = (($Time < timeFinal/3.0) ? $Time * rate :
                    ($Time < 2.0*timeFinal/3.0 ? hmax : hmax - ($Time - 2.0*timeFinal/3.0) * rate));
    EndIf
}


Constraint {
    { Name phi ;
        Case {
            {Region SurfOut ; Value XYZ[]*directionApplied[] ; TimeFunction hsVal[] ;}
            {Region SurfSym_ht0 ; Value 0. ;} // If symmetry (and then, use only purely vertical hs!)
        }
    }
    { Name h ;
        Case {
            {Region SurfSym_ht0 ; Value 0. ;}
        }
    }
    { Name j ;
        Case {
        }
    }
    { Name Current ;
        Case {
        }
    }
    { Name Voltage ;
        Case {
        }
    }
}

Include "../lib/jac_int.pro";
Include "../lib/simple_formulations.pro";
Include "../lib/simple_resolution.pro";

PostOperation {
    { Name MagDyn; NameOfPostProcessing MagDyn_htot;
        Operation {
            Print[ phi, OnElementsOf OmegaCC , File "res/phi.pos", Name "phi [A]" ];
            Print[ j, OnElementsOf OmegaC , File "res/j.pos", Name "j [A/m2]" ];
            Print[ e, OnElementsOf OmegaC , File "res/e.pos", Name "e [V/m]" ];
            Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h [A/m]" ];
            Print[ b, OnElementsOf Omega , File "res/b.pos", Name "b [T]" ];
        }
    }
}

DefineConstant[
  R_ = {"MagDyn", Name "GetDP/1ResolutionChoices", Visible 0},
  C_ = {"-solve -pos -bin -v 3 -v2", Name "GetDP/9ComputeCommand", Visible 0},
  P_ = { "MagDyn", Name "GetDP/2PostOperationChoices", Visible 0}
];
