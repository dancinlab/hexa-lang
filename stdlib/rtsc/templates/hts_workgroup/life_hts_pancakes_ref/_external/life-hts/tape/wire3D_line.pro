Include "wire3D_data.pro";
Include "../lib/commonInformation.pro";

Group {
    // Output choice
    DefineConstant[onelabInterface = {0, Choices{0,1}, Name "Input/3Problem/2Show solution during simulation?"}]; // Set to 0 for launching in terminal (faster)
    realTimeInfo = 1;
    realTimeSolution = onelabInterface;
    // ------- PROBLEM DEFINITION -------
    // Test name - for output files
    name = "tape";
    // (directory name for .txt files, not .pos files)
    DefineConstant [testname = "test"];
    // Dimension of the problem
    Dim = 3;

    Flag_cohomology = 0;
    // Source:
    //      0 -> applied current
    //      1 -> applied field
    SourceType = 0;

    // ------- WEAK FORMULATION -------
    // Choice of the formulation
    formulation = (preset==1) ? h_formulation : ((preset == 4) ? ta_formulation : ((preset == 5) ? h_phi_ts_formulation : a_formulation));

    alt_formulation = 0;
    // ------- Definition of the physical regions -------
    // Material type of region MATERIAL, 0: air, 1: super, 2: copper, 3: soft ferro
    MaterialType = 1;
    // Filling the regions
    Air = Region[ AIR ];
    Air += Region[ AIR_OUT ];
    If(MaterialType == 0)
        Air += Region[ WIRE ];
    ElseIf(MaterialType == 1 || MaterialType == 2)
        Cond = Region[ WIRE ];
        Electrode1 += Region[ SURF_SYM_MAT1 ];
        BndOmegaC += Region[ BND_WIRE ];
        BndOmegaC_side += Region[ BND_WIRE_SIDE ];
        If (Flag_cohomology == 0)
            Cuts = Region[ {CUT} ];
        Else
            Cuts = Region[ {THICK_CUT} ]; // Cohomology basis representatives = thick cuts
        EndIf
        If(MaterialType == 1)
            Super += Region[ WIRE ];
            IsThereSuper = 1;
        ElseIf(MaterialType == 2)
            Copper += Region[ WIRE ];
        EndIf
    ElseIf(MaterialType == 3)
        Ferro += Region[ WIRE ];
        IsThereFerro = 1;
    EndIf
    // Edges of the tape: to be used by the ta_formulation and the h_phi_ts_formulation
    Edge1 = Region[ EDGE_1 ];
    Edge2 = Region[ EDGE_2 ];
    LateralEdges = Region[ {Edge1, Edge2} ];
    PositiveEdges = Region[ {Edge1} ];

    Electrodes = Region[ {Electrode1} ];
    // Positive and negative sides (UP and DOWN - 1 and 0) of the shell representing the tape in the h_phi_ts_formulation
    GammaS_1 = Region[ SHELL_UP ];
    GammaS_0 = Region[ SHELL_DOWN ];
    GammaS = Region[{GammaS_0, GammaS_1}];

    // Fill the regions for formulation
    MagnAnhyDomain = Region[ {Ferro} ];
    MagnLinDomain = Region[ {Air, Super, Copper} ];
    If (formulation != h_phi_ts_formulation)
        NonLinOmegaC = Region[ {Super} ];
    Else
        NonLinOmegaC = Region[ {GammaS} ];
    EndIf
    LinOmegaC = Region[ {Copper} ];
    OmegaC = Region[ {LinOmegaC, NonLinOmegaC} ];
    OmegaCC = Region[ {Air, Ferro} ];
    Omega = Region[ {OmegaC, OmegaCC} ];
    ArbitraryPoint = Region[ ARBITRARY_POINT ]; // To fix the potential

    // Boundaries for BC
    SurfOut = Region[ SURF_OUT ];
    SurfSym = Region[ SURF_SYM ];
    If(SourceType == 1)
        Gamma_h = Region[{SurfOut}];
        Gamma_e = Region[{SurfSym}];
    Else
        Gamma_h = Region[{}];
        Gamma_e = Region[{SurfSym, SurfOut}];
    EndIf
    GammaAll = Region[ {Gamma_h, Gamma_e} ];
}


Function{
    // ------- PARAMETERS -------
    // Superconductor parameters
    DefineConstant [jc = {2.5e10, Name "Input/3Material Properties/2jc (Am⁻²)"}]; // Critical current density [A/m2]
    DefineConstant [n = {25, Name "Input/3Material Properties/1n (-)"}]; // Superconductor exponent (n) value [-]
    // Ferromagnetic material parameters
    DefineConstant [mur0 = 1700.0]; // Relative permeability at low fields [-]
    DefineConstant [m0 = 1.04e6]; // Magnetic field at saturation [A/m]

    // Excitation
    DefineConstant [IFraction = {0.9, Name "Input/4Source/0Fraction of max. current intensity (-)"}];
    DefineConstant [Imax = IFraction*jc*W_tape*H_tape]; // Maximum imposed current intensity [A]
    DefineConstant [bmax = 2e3*1e-4];
    DefineConstant [f = 50]; // Frequency of imposed current intensity [Hz]
    DefineConstant [timeStart = 0]; // Initial time [s]
    DefineConstant [timeFinal = 1.25/f]; // Final time for source definition [s]
    DefineConstant [timeFinalSimu = 0.25/f]; // Final time of simulation [s]

    // Numerical parameters
    DefineConstant [nbStepsPerPeriod = {(preset!=2) ? 240/meshMult : 8, Highlight "LightBlue",
        ReadOnly !expMode, Name "Input/5Method/Number of time step per period (-)"}]; // Number of time steps over one period [-]
    DefineConstant [dt = 1/(nbStepsPerPeriod*f)]; // Time step (initial if adaptive)[s]
    DefineConstant [writeInterval = dt]; // Time interval between two successive output file saves [s]
    DefineConstant [dt_max = dt]; // Maximum allowed time step [s]
    DefineConstant [iter_max = {(preset==1 || preset==4 || preset==5) ? 400 : 600, Highlight "LightBlue",
        ReadOnly !expMode, Name "Input/5Method/Max number of iteration (-)"}]; // Maximum number of nonlinear iterations
    DefineConstant [extrapolationOrder = 2]; // Extrapolation order
    DefineConstant [tol_energy = {(preset==1 || preset==4 || preset==5) ? 1e-6 : 1e-4, Highlight "LightBlue",
        ReadOnly !expMode, Name "Input/5Method/Relative tolerance (-)"}]; // Relative tolerance on the energy estimates
    // Control points
    controlPoint1 = {-W_tape/2+1e-5,0, 0}; // CP1
    controlPoint2 = {W_tape/2-1e-5, 0, 0}; // CP2
    controlPoint3 = {0, H_tape/2+2e-3, 0}; // CP3
    controlPoint4 = {W_tape, H_tape/2+2e-3, 0}; // CP4
    DefineConstant [savedPoints = 500]; // Resolution of the line saving postprocessing
}

Include "../lib/lawsAndFunctions.pro";

Function{
    // Sine source field
    controlTimeInstants = {timeFinalSimu, 1/(2*f), 1/f, 3/(2*f), 2*timeFinal};
    I[] = Imax * Sin[2.0 * Pi * f * $Time];
    hsVal[] = 1/mu0 * bmax * Sin[2.0 * Pi * f * $Time];
    // For the t-a-formulation
    thickness[Cond] = H_tape;
    thickness[Edge1] = H_tape;
    thickness[Air] = H_tape; // Fix me, doesn't make sense to define it here...

    directionApplied[] = Vector[0., 0., 1.];
}

Constraint {
    { Name a ;
        Case {
            If(SourceType == 0)
                {Region SurfOut ; Value 0.0;}
                {Region SurfSym ; Value 0.0;}
            ElseIf(SourceType == 1)
                // {Region SurfOut ; Value -X[] * mu0 ; TimeFunction hsVal[] ;}
                {Region SurfSym ; Value 0.0;}
            EndIf
        }
    }
    { Name a2 ;
        Case {
        }
    }
    { Name h ;
        Case {
        }
    }
    { Name j ;
        Case {
            {Region SurfSym ; Value 0.0;}
        }
    }
    { Name phi ;
        Case {
            If(SourceType == 0)
                {Region ArbitraryPoint ; Value 0.0;} // If no surf sym (we could have put one here), fix it at one point
            ElseIf(SourceType == 1)
                {Region SurfOut ; Value XYZ[]*directionApplied[] ; TimeFunction hsVal[] ;}
            EndIf
        }
    }
    { Name Current ; Type Assign;
        Case {
            If(formulation == h_formulation || formulation == coupled_formulation || formulation == h_phi_ts_formulation)
                // h-formulation and cuts
                If(SourceType == 0)
                    { Region Cuts; Value 1.0; TimeFunction I[]; }
                ElseIf(SourceType == 1)
                    { Region Cuts; Value 0; }
                EndIf
            Else
                // a-formulation and BF_RegionZ
                If(SourceType == 0)
                    If(Dim == 2)
                        { Region Cond; Value 1.0; TimeFunction I[]; }
                    Else
                        { Region Electrode1; Value  1.0; TimeFunction I[]; }
                    EndIf
                ElseIf(SourceType == 1)
                    If(Dim == 2)
                        { Region Cond; Value 0.0; }
                    Else
                        { Region Electrode1; Value 0.0; }
                    EndIf
                EndIf
            ElseIf(formulation == ta_formulation)
                // t-a-formulation
                If(SourceType == 0)
                    { Region Edge1; Value 1.0; TimeFunction I[]; } // t_tilde = w t
                ElseIf(SourceType == 1)
                    { Region Edge1; Value 0.0; }
                EndIf
            EndIf
        }
    }
    { Name Voltage ; Case { } } // Nothing

    { Name Connect; // required link Dofs in the h-phi_ts_formulation
		Case {
				{ Region GammaS_1; Type Link ; RegionRef GammaS_0;
					Coefficient 1; Function Vector[$X,$Y,$Z] ;
				}
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
        ElseIf(formulation == ta_formulation)
            NameOfPostProcessing MagDyn_ta ;
        ElseIf(formulation == h_phi_ts_formulation)
            NameOfPostProcessing MagDyn_hphits ;
        EndIf
        Operation{
            Print[ time[OmegaC], OnRegion OmegaC, LastTimeStepOnly, Format Table, SendToServer "Output/0Time [s]"] ;
            If(formulation == h_formulation)
                Print[ I, OnRegion Cuts, LastTimeStepOnly, Format Table, SendToServer "Output/1Applied current [A]"] ;
                Print[ V, OnRegion Cuts, LastTimeStepOnly, Format Table, SendToServer "Output/2Tension [Vm^-1]"] ;
            ElseIf(formulation == a_formulation)
                Print[ I, OnRegion OmegaC, LastTimeStepOnly, Format Table, SendToServer "Output/1Applied current [A]"] ;
                Print[ U, OnRegion OmegaC, LastTimeStepOnly, Format Table, SendToServer "Output/2Tension [Vm^-1]"] ;
            ElseIf(formulation == ta_formulation)
                Print[ I, OnRegion PositiveEdges, LastTimeStepOnly, Format Table, SendToServer "Output/1Applied current [A]"] ;
                Print[ V, OnRegion PositiveEdges, LastTimeStepOnly, Format Table, SendToServer "Output/2Tension [Vm^-1]"] ;
            EndIf
            //Print[ dissPower[OmegaC], OnGlobal, LastTimeStepOnly, Format Table, SendToServer "Output/3Joule loss [W]"] ;
        }
    }
    { Name MagDyn;LastTimeStepOnly realTimeSolution ;
        If(formulation == h_formulation)
            NameOfPostProcessing MagDyn_htot;
        ElseIf(formulation == a_formulation)
            NameOfPostProcessing MagDyn_avtot;
        ElseIf(formulation == coupled_formulation)
            NameOfPostProcessing MagDyn_coupled;
        ElseIf(formulation == ta_formulation)
            NameOfPostProcessing MagDyn_ta ;
        ElseIf(formulation == h_phi_ts_formulation)
            NameOfPostProcessing MagDyn_hphits ;
        EndIf
        Operation {
            If(economPos == 0)
                If(formulation == h_formulation || formulation == h_phi_ts_formulation)
                    Print[ phi, OnElementsOf OmegaCC , File "res/phi.pos", Name "phi [A]" ];
                ElseIf(formulation == a_formulation)
                    Print[ a, OnElementsOf Omega , File "res/a.pos", Name "a [Tm]" ];
                    Print[ ur, OnElementsOf OmegaC , File "res/ur.pos", Name "ur [V/m]" ];
                    If(alt_formulation)
                        Print[ j_alt, OnElementsOf OmegaC , File "res/j_alt.pos", Name "j [A/m2]" ];
                    EndIf
                ElseIf(formulation == ta_formulation)
                    Print[ a, OnElementsOf Omega , File "res/a.pos", Name "a [Tm]" ];
                    Print[ t, OnElementsOf OmegaC , File "res/t.pos", Name "t [Am]" ];
                    Print[ t, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                        Format TimeTable, File "res/tLine.txt"];
                EndIf
                If(formulation != h_phi_ts_formulation)
                    Print[ j, OnElementsOf OmegaC , File "res/j.pos", Name "j [A/m2]" ];
                    Print[ e, OnElementsOf OmegaC , File "res/e.pos", Name "e [V/m]" ];
                EndIf
                If(formulation != ta_formulation && formulation != h_phi_ts_formulation)
                    Print[ jz, OnElementsOf OmegaC , File "res/jz.pos", Name "jz [A/m2]" ];
                EndIf

                Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h [A/m]" ];
                If(formulation == ta_formulation)
                    Print[ b, OnElementsOf OmegaCC , File "res/b.pos", Name "b [T]" ];
                ElseIf(formulation == h_phi_ts_formulation)
                    Print[ b, OnElementsOf Air , File "res/b.pos", Name "b [T]" ];
                Else
                    Print[ b, OnElementsOf Omega , File "res/b.pos", Name "b [T]" ];
                EndIf
            EndIf
            If(formulation != h_phi_ts_formulation && formulation != ta_formulation && Dim != 3)
                Print[ j, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                    Format TimeTable, File outputCurrent];
            ElseIf(formulation == ta_formulation)
                Print[ j, OnElementsOf OmegaC, Format TimeTable, File outputCurrent];
            EndIf
            Print[ b, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                Format TimeTable, File outputMagInduction1];
            Print[ b, OnLine{{List[controlPoint3]}{List[controlPoint4]}} {savedPoints},
                Format TimeTable, File outputMagInduction2];
            If(formulation == h_phi_ts_formulation)
                For i In {1:N_ele} // Normalized current density in each virtual element
                    Print[ hi~{i}, OnElementsOf GammaS_0, File Sprintf("res/h_%g.pos", i), Name Sprintf("h(%g)",i) ];
                    Print[ jijc~{i}, OnElementsOf GammaS_0, File Sprintf("res/j_jc_%g.pos", i), Name Sprintf("j_jc(%g)",i) ];
                    Print[ ji~{i}, OnElementsOf GammaS_0, File Sprintf("res/j_%g.pos", i), Name Sprintf("j(%g)",i) ];
                EndFor
            EndIf
            Print[ hsVal[Omega], OnRegion Omega, Format TimeTable, File outputAppliedField];
        }
    }
}

DefineConstant[
  R_ = {"MagDyn", Name "GetDP/1ResolutionChoices", Visible 0},
  C_ = {"-solve -pos -bin -v 3 -v2", Name "GetDP/9ComputeCommand", Visible 0},
  P_ = { "MagDyn", Name "GetDP/2PostOperationChoices", Visible 0}
];
