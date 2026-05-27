Include "cylinders_data.pro";
Include "../lib/commonInformation.pro";

Group {
    // Preset choice of formulation
    DefineConstant[preset = {4, Highlight "Blue",
      Choices{
        1="h-formulation",
        3="a-formulation (small steps)",
        4="h-a-formulation"},
      Name "Input/5Method/0Preset formulation" },
      expMode = {0, Choices{0,1}, Name "Input/5Method/1Allow changes?"}];
    // Output choice
    DefineConstant[onelabInterface = {0, Choices{0,1}, Name "Input/3Problem/2Show solution during simulation?"}]; // Set to 0 for launching in terminal (faster)
    realTimeInfo = 1;
    realTimeSolution = onelabInterface;

    alt_formulation = 0; // Experimental for a-formulation (normally ok with h-form.)

    economPos = 0;
    Homogenized = 1;
    factor = 1;

    // ------- PROBLEM DEFINITION -------
    // Test name - for output files
    name = "cylinder";
    // (directory name for .txt files, not .pos files)
    testname = "cylinders_test";
    // Dimension of the problem
    Dim = 2;
    // Axisymmetry of the problem, 0: no, 1: yes
    Axisymmetry = 1;

    // ------- WEAK FORMULATION -------
    // Choice of the formulation
    formulation = (preset==1) ? h_formulation : ((preset == 3) ? a_formulation : coupled_formulation);
    // ------- Definition of the physical regions -------
    // What cylinders are made up of? 0: none (air), 1: super, 2: ferro, 3: both
    MaterialsType = 3;
    // Filling the regions
    Air = Region[ AIR ];
    Air += Region[ AIR_OUT ];
    If(MaterialsType == 0)
        Air += Region[ SUPER ];
        Air += Region[ FERRO ];
    ElseIf(MaterialsType == 1)
        Super += Region[ SUPER ];
        BndOmegaC += Region[ BND_OMEGA_C ];
        IsThereSuper = 1;
        Air += Region[ FERRO ];
    ElseIf(MaterialsType == 2)
        Air += Region[ SUPER ];
        Ferro = Region[ FERRO ];
        IsThereFerro = 1;
    ElseIf(MaterialsType == 3)
        Super += Region[ SUPER ];
        BndOmegaC += Region[ BND_OMEGA_C ];
        Ferro += Region[ FERRO ];
        IsThereSuper = 1;
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
    CentralPoint = Region[ ARBITRARY_POINT ];
    SurfOut = Region[ SURF_OUT ];
    SurfSym = Region[ SURF_SYM ];
    SurfSym += Region[ SURF_SYM_MAT ];
    If(formulation == h_formulation)
        Gamma_h = Region[{SurfOut}]; // Essential BC
        Gamma_e = Region[{SurfSym}]; // Natural BC
    ElseIf(formulation == a_formulation)
        Gamma_h = Region[{}]; // Natural BC
        Gamma_e = Region[{SurfOut, SurfSym}]; // Essential BC
    ElseIf(formulation == coupled_formulation)
        Gamma_h = Region[{}];
        Gamma_e = Region[{SurfOut, SurfSym}];
    EndIf
    GammaAll = Region[ {Gamma_h, Gamma_e} ];
}

Function{
    // ------- PARAMETERS -------
    // Superconductor parameters
    DefineConstant [jc = {3e8, Name "Input/3Material Properties/2jc (Am⁻²)"}]; // Critical current density [A/m2]
    DefineConstant [n = {20, Name "Input/3Material Properties/1n (-)"}]; // Superconductor exponent (n) value [-]
    // Ferromagnetic material parameters
    DefineConstant [mur0 = {1700.0, Name "Input/3Material Properties/3mur at low fields (-)"}]; // Relative permeability at low fields [-]
    DefineConstant [m0 = {1.04e6, Name "Input/3Material Properties/4Saturation field (Am^-1)"}]; // Magnetic field at saturation [A/m]
    // Excitation - Source field or imposed current intensty
    // 0: sine, 1: triangle, 2: up-down-pause, 3: step, 4: up-pause-down
    DefineConstant [Flag_Source = {1, Highlight "yellow", Choices{
        0="Sine",
        1="Triangle",
        4="Up-pause-down"}, Name "Input/4Source/0Source field type" }];
    DefineConstant [f = {0.1, Visible (Flag_Source ==0), Name "Input/4Source/1Frequency (Hz)"}]; // Frequency of imposed current intensity [Hz]
    DefineConstant [bmax = {1.5, Name "Input/4Source/2Field amplitude (T)"}]; // Maximum applied magnetic induction [T]
    DefineConstant [partLength = {5, Visible (Flag_Source != 0), Name "Input/4Source/1Ramp duration (s)"}];
    DefineConstant [timeStart = 0]; // Initial time [s]
    DefineConstant [timeFinal = (Flag_Source == 0) ? 5/(4*f) : ((Flag_Source == 1) ? 5*partLength : 3*partLength)]; // Final time for source definition [s]
    DefineConstant [timeFinalSimu = timeFinal]; // Final time of simulation [s]

    // ------- NUMERICAL PARAMETERS -------
    DefineConstant [dt = {meshMult*timeFinal/600, Highlight "LightBlue",
        ReadOnly !expMode, Name "Input/5Method/Time step (s)"}]; // Time step (initial if adaptive)[s]
    DefineConstant [writeInterval = dt]; // Time interval between two successive output file saves [s]
    DefineConstant [dt_max = dt]; // Maximum allowed time step [s]
    DefineConstant [tol_energy = {(preset == 3 && alt_formulation == 0) ? 1e-4 : 1e-6, Highlight "LightBlue",
        ReadOnly !expMode, Name "Input/5Method/Relative tolerance (-)"}]; // Relative tolerance on the energy estimates
    DefineConstant [iter_max = {(preset==3) ? 600 : 50, Highlight "LightBlue",
        ReadOnly !expMode, Name "Input/5Method/Max number of iteration (-)"}]; // Maximum number of nonlinear iterations
    DefineConstant [extrapolationOrder = (preset==3) ? 1 : 1]; // Extrapolation order
    // Control points
    controlPoint1 = {1e-5,0, 0}; // CP1
    controlPoint2 = {W/2-1e-5, 0, 0}; // CP2
    controlPoint3 = {0, 2*H_super/2+2e-5, 0}; // CP3
    controlPoint4 = {W/2, 2*H_super/2+2e-5, 0}; // CP4
    controlPoint5 = {0, 3*H_super/2+2e-5, 0}; // CP3
    controlPoint6 = {W/2, 3*H_super/2+2e-5, 0}; // CP4
    savedPoints = 500; // Resolution of the line saving postprocessing
}

Include "../lib/lawsAndFunctions.pro";

Function{
    // Direction of applied field
    directionApplied[] = Vector[0., 1., 0.]; // Only choice for axi
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
}


// Only external field is implemented
Constraint {
    { Name a ;
        Case {
            If(Axisymmetry)
                // Square for axisymmetry because circulation on perpendicular edge
                {Region Gamma_e ; Value -X[]^2 * mu0 / 2.0 ; TimeFunction hsVal[] ;}
            Else
                {Region Gamma_e ; Value -X[] * mu0 ; TimeFunction hsVal[] ;}
            EndIf
        }
    }
    { Name a2 ;
        Case {
            {Region Gamma_e ; Value 0.0 ;} // Second-order hierarchical elements for coupled formulation
        }
    }
    { Name phi ;
        Case {
            {Region Gamma_h ; Value XYZ[]*directionApplied[] ; TimeFunction hsVal[] ;}
        }
    }
    { Name h ;
        Case {
        }
    }
    { Name j ;
        Case {
            {Region SurfSym ; Value 0.0 ;}
        }
    }
    { Name Voltage ;
        Case {
            If(formulation == h_formulation || formulation == coupled_formulation)
            // No cut is defined in this geometry (no applied current) -> No associated constraint
            Else
                // a-formulation and BF_RegionZ
                { Region OmegaC; Value 0.0; }
            EndIf
        }
    }
    { Name Current ;
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
            Print[ m_avg_y_tesla[OmegaC], OnGlobal, LastTimeStepOnly, Format Table, SendToServer "Output/2Avg. magnetization [T]"] ;
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
                    Print[ mur, OnElementsOf OmegaCC , File "res/mur.pos", Name "mur [-]" ];
                    If(alt_formulation)
                        Print[ b_alt, OnElementsOf Ferro , File "res/b_alt.pos", Name "b_alt [T]" ];
                    EndIf
                ElseIf(formulation == a_formulation)
                    Print[ a, OnElementsOf Omega , File "res/a.pos", Name "a [Tm]" ];
                    Print[ ur, OnElementsOf OmegaC , File "res/ur.pos", Name "ur [V/m]" ];
                    Print[ mur, OnElementsOf OmegaCC , File "res/mur.pos", Name "mur [-]" ];
                ElseIf(formulation == coupled_formulation)
                    //Print[ phi, OnElementsOf BndOmegaC , File "res/phi.pos", Name "phi [A]" ];
                    Print[ a, OnElementsOf OmegaCC , File "res/a.pos", Name "a [Tm]" ];
                    Print[ mur, OnElementsOf OmegaCC , File "res/mur.pos", Name "mur [-]" ];
                EndIf
                Print[ j, OnElementsOf OmegaC , File "res/j.pos", Name "j [A/m2]" ];
                Print[ jz, OnElementsOf OmegaC , File "res/jz.pos", Name "j [A/m2]" ];
                Print[ e, OnElementsOf OmegaC , File "res/e.pos", Name "e [V/m]" ];
                Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h [A/m]" ];
                Print[ b, OnElementsOf Omega , File "res/b.pos", Name "b [T]" ];
                If(alt_formulation && formulation == h_formulation)
                    Print[ b_alt, OnElementsOf OmegaCC , File "res/b_alt.pos", Name "b_alt [T]" ];
                    Print[ h_alt, OnElementsOf MagnAnhyDomain , File "res/h_alt.pos", Name "h_alt [T]" ];
                ElseIf(alt_formulation && formulation == a_formulation)
                    Print[ j_alt, OnElementsOf OmegaC , File "res/j_alt.pos", Name "j_alt [A/m2]" ];
                EndIf
            EndIf
            If(alt_formulation && formulation == a_formulation)
                Print[ j_alt, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                    Format TimeTable, File outputCurrent];
            Else
                Print[ j, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                    Format TimeTable, File outputCurrent];
            EndIf
            Print[ b, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                Format TimeTable, File outputMagInduction1];
            If(alt_formulation && formulation == h_formulation)
                Print[ b_alt, OnLine{{List[controlPoint3]}{List[controlPoint4]}} {savedPoints},
                    Format TimeTable, File outputMagInduction2];
            Else
                Print[ b, OnLine{{List[controlPoint3]}{List[controlPoint4]}} {savedPoints},
                    Format TimeTable, File outputMagInduction2];
            EndIf
            Print[ b, OnLine{{List[controlPoint5]}{List[controlPoint6]}} {savedPoints},
                Format TimeTable, File outputMagInduction3];
            Print[ b, OnPlane{{List[controlPoint1]}{List[controlPoint2]}{List[controlPoint3]}} {100,50},
                File "res/b_onPlane.pos", Format Gmsh];
            Print[ hsVal[Omega], OnRegion Omega, Format TimeTable, File outputAppliedField];
        }
    }
}

DefineConstant[
  R_ = {"MagDyn", Name "GetDP/1ResolutionChoices", Visible 0},
  C_ = {"-solve -pos -bin -v 3 -v2", Name "GetDP/9ComputeCommand", Visible 0},
  P_ = { "MagDyn", Name "GetDP/2PostOperationChoices", Visible 0}
];
