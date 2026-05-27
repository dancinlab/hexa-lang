Include "cube_data.pro";
Include "../lib/commonInformation.pro";

Group {
    // Output choice
    DefineConstant[onelabInterface = {0, Choices{0,1}, Name "Input/3Problem/2Show solution during simulation?"}]; // Set to 0 for launching in terminal (faster)
    realTimeInfo = 0;
    realTimeSolution = onelabInterface;
    // ------- PROBLEM DEFINITION -------
    // Test name - for output files
    name = "cube";
    // (directory name for .txt files, not .pos files)
    testname = "cube_model";
    // Dimension of the problem
    Dim = 3;
    // Axisymmetry of the problem
    Axisymmetry = 0; // Not axi

    // ------- WEAK FORMULATION -------
    // Choice of the formulation
    formulation = h_formulation;

    // ------- Definition of the physical regions -------
    // Material type of region MATERIAL, 0: air, 1: super, 2: copper, 3: soft ferro
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
    ElseIf(MaterialType == 3)
        Ferro += Region[ MATERIAL ];
        IsThereFerro = 1;
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
    // Ferromagnetic material parameters
    DefineConstant [mur0 = 1700.0]; // Relative permeability at low fields [-]
    DefineConstant [m0 = 1.04e6]; // Magnetic field at saturation [A/m]

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
    DefineConstant [writeInterval = dt]; // Time interval between two successive output file saves [s]
    DefineConstant [dt_max = dt]; // Maximum allowed time step [s]
    DefineConstant [tol_energy = 1e-6]; // Relative tolerance on the energy estimates (1e-10 for j distr. as in the article)
    DefineConstant [iter_max = 100]; // Maximum number of nonlinear iterations
    DefineConstant [extrapolationOrder = 1]; // Extrapolation order
    // Control points
    controlPoint1 = {1e-5,0, 0}; // CP1
    controlPoint2 = {a/2-1e-5, 0, 0}; // CP2
    controlPoint3 = {0, a/2+2e-3, 0}; // CP3
    controlPoint4 = {a/2, a/2+2e-3, 0}; // CP4
    savedPoints = 2000; // Resolution of the line saving postprocessing
}

Include "../lib/lawsAndFunctions.pro";

Function{
    // Direction of applied field
    directionApplied[] = Vector[0., 0., 1.]; // Only possible choice provided the symmetry of the geometry
    hmax = bmax / mu0;
    If(Flag_Source == 0)
        // Sine source field
        controlTimeInstants = {timeFinalSimu, 1/(2*f), 1/f, 3/(2*f), 2*timeFinal};
        hsVal[] = hmax * Sin[2.0 * Pi * f * $Time];
    ElseIf(Flag_Source == 1)
        // Triangle source field (5/4 of a complete cycle)
        controlTimeInstants = {timeFinal, timeFinal/5.0, 3.0*timeFinal/5.0, timeFinal};
        rate = hmax * 5.0 / timeFinal;
        hsVal[] = (($Time < timeFinal/5.0) ? $Time * rate :
                    ($Time >= timeFinal/5.0 && $Time < 3.0*timeFinal/5.0) ?
                    hmax - ($Time - timeFinal/5.0) * rate :
                    - hmax + ($Time - 3.0*timeFinal/5.0) * rate);
    ElseIf(Flag_Source == 4)
        // Up-pause-down
        controlTimeInstants = {timeFinal/3.0, 2.0*timeFinal/3.0, timeFinal};
        rate = hmax * 3.0 / timeFinal;
        hsVal[] = (($Time < timeFinal/3.0) ? $Time * rate :
                    ($Time < 2.0*timeFinal/3.0 ? hmax : hmax - ($Time - 2.0*timeFinal/3.0) * rate));
    EndIf
    /*
    rho_inf = 0.01;
    rho[Super] = rho_power[$1,$2]*TensorDiag[1,1,1] + TensorDiag[0,0,rho_inf];
    dedj_power_aniso[] = (1.0/$relaxFactor) *
        (ec / jcb[$2] * (Min[($TimeStep<-1)?1.5*jcb[$2]:1e99, Norm[$1]]/jcb[$2])^(nb[$2]#7 - 1) * TensorDiag[1, 1, 1] + rho_inf * TensorDiag[0, 0, 1] +
        ec / jcb[$2]^3 * (#7 - 1) * (Min[($TimeStep<-1)?1.5*jcb[$2]:1e99, Norm[$1]]/jcb[$2])^(#7 - 3) * SquDyadicProduct[$1]);
    dedj[Super] = dedj_power_aniso[$1,$2];

    sigma[Super] = TensorDiag[sigma_power[$1,$2], sigma_power[$1,$2], sigma_power[$1,$2]/100];
    djde[Super] = djde_power[$1,$2];
    */
}


Constraint {
    { Name a ;
        Case {
            {Region SurfSym_bn0; Value 0.0;}
        }
    }
    { Name a2 ;
        Case {
        }
    }
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
Include "../lib/formulations.pro";
Include "../lib/resolution.pro";

PostOperation {
    // Runtime output for graph plot
    { Name Info;
        If(formulation == h_formulation)
            NameOfPostProcessing MagDyn_htot ;
        ElseIf(formulation == a_formulation)
            NameOfPostProcessing MagDyn_avtot ;
        ElseIf(formulation == coupled_formulation)
            NameOfPostProcessing MagDyn_coupled ;
        EndIf
        Operation{
            Print[ time[OmegaC], OnRegion OmegaC, LastTimeStepOnly, Format Table, SendToServer "Output/0Time [s]"] ;
            Print[ bsVal[OmegaC], OnRegion OmegaC, LastTimeStepOnly, Format Table, SendToServer "Output/1Applied field [T]"] ;
            Print[ dissPower[OmegaC], OnGlobal, LastTimeStepOnly, Format Table, SendToServer "Output/2Joule loss [W]"] ;
        }
    }
    { Name MagDyn;LastTimeStepOnly realTimeSolution ;
        If(formulation == h_formulation)
            NameOfPostProcessing MagDyn_htot;
        ElseIf(formulation == a_formulation)
            NameOfPostProcessing MagDyn_avtot;
        ElseIf(formulation == coupled_formulation)
            NameOfPostProcessing MagDyn_coupled;
        EndIf
        Operation {
            If(economPos == 0)
                If(formulation == h_formulation)
                    Print[ phi, OnElementsOf OmegaCC , File "res/phi.pos", Name "phi [A]" ];
                ElseIf(formulation == a_formulation)
                    Print[ a, OnElementsOf Omega , File "res/a.pos", Name "a [Tm]" ];
                    Print[ ur, OnElementsOf OmegaC , File "res/ur.pos", Name "ur [V/m]" ];
                EndIf
                Print[ j, OnElementsOf OmegaC , File "res/j.pos", Name "j [A/m2]" ];
                Print[ e, OnElementsOf OmegaC , File "res/e.pos", Name "e [V/m]" ];
                Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h [A/m]" ];
                Print[ b, OnElementsOf Omega , File "res/b.pos", Name "b [T]" ];
            EndIf
            Print[ j, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                Format TimeTable, File outputCurrent];
            Print[ b, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                Format TimeTable, File outputMagInduction1];
            Print[ b, OnLine{{List[controlPoint3]}{List[controlPoint4]}} {savedPoints},
                Format TimeTable, File outputMagInduction2];
            Print[ hsVal[Omega], OnRegion Omega, Format TimeTable, File outputAppliedField];
        }
    }
}

DefineConstant[
  R_ = {"MagDyn", Name "GetDP/1ResolutionChoices", Visible 0},
  C_ = {"-solve -pos -bin -v 3 -v2", Name "GetDP/9ComputeCommand", Visible 0},
  P_ = { "MagDyn", Name "GetDP/2PostOperationChoices", Visible 0}
];
