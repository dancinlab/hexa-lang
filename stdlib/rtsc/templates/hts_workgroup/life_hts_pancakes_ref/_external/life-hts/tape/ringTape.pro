Include "ringTape_data.pro";
Include "../lib/commonInformation.pro";

Group {
    // Output choice
    realTimeInfo = 1;
    realTimeSolution = 0;

    // ------- PROBLEM DEFINITION -------
    // Test name - for output files
    name = "tape";
    // (directory name for .txt files, not .pos files)
    DefineConstant [testname = "ringTape"];
    // Dimension of the problem
    Dim = 3;

    // Source:
    //      0 -> applied current
    //      1 -> applied field
    SourceType = 1;

    // ------- WEAK FORMULATION -------
    // Choice of the formulation
    formulation = ta_formulation;
    Flag_cohomology = 0;

    // ------- Definition of the physical regions -------
    // Material type of region MATERIAL, 1: super, 2: copper
    MaterialType = 1;
    // Filling the regions
    Air = Region[ AIR ];
    Cond = Region[ WIRE ];
    BndOmegaC = Region[ BND_WIRE ];
    If (Flag_cohomology == 0)
        Cuts = Region[ {CUT} ];
        BndOmegaC_side = Region[ BND_WIRE_SIDE ];
    Else
        Cuts = Region[ {THICK_CUT} ]; // Cohomology basis representatives = thick cuts
    EndIf
    If(MaterialType == 1)
        Super += Region[ WIRE ];
        IsThereSuper = 1; // Do not forget this!
    ElseIf(MaterialType == 2)
        Copper += Region[ WIRE ];
    EndIf

    // Edges of the tape: to be used by the ta_formulation and the h_phi_ts_formulation
    Edge1 = Region[ EDGE_1 ];
    Edge2 = Region[ EDGE_2 ];
    LateralEdges = Region[ {Edge1, Edge2} ];
    PositiveEdges = Region[ {Edge1} ];

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
    SurfSym = Region[ {} ];
    If(SourceType == 1) // Applied field
        Gamma_h = Region[{SurfOut}]; // Essential for h-phi, natural for a or t-a
        Gamma_e = Region[{}]; // Empty here, not symmetry surfaces
    Else // Applied current intensity
        If(formulation == ta_formulation || formulation == a_formulation)
            Gamma_h = Region[{}];
            Gamma_e = Region[{SurfOut}]; // Essential BC for b-conform formulation
        Else
            Gamma_h = Region[{SurfOut}]; // Essential BC for h-conform formulations
            Gamma_e = Region[{}];
        EndIf
    EndIf
    GammaAll = Region[ {Gamma_h, Gamma_e} ];
}


Function{
    // ------- PARAMETERS -------
    // Superconductor parameters
    DefineConstant [jc = 2.5e10]; // Critical current density [A/m2]
    DefineConstant [n = 25]; // Superconductor exponent (n) value [-]

    // Excitation
    DefineConstant [IFraction = 0.9];
    DefineConstant [Imax = IFraction*jc*w_wire*h_wire]; // Maximum imposed current intensity [A]
    DefineConstant [bmax = 2e-2]; // Maximum applied flux density [T]
    DefineConstant [f = 50]; // Frequency of imposed current intensity [Hz]
    DefineConstant [timeStart = 0]; // Initial time [s]
    DefineConstant [timeFinal = 1.25/f]; // Final time for source definition [s]
    DefineConstant [timeFinalSimu = 0.25/f]; // Final time of simulation [s]

    // Numerical parameters
    DefineConstant [nbStepsPerPeriod = 240/meshMult]; // Number of time steps over one period [-]
    DefineConstant [dt = 1/(nbStepsPerPeriod*f)]; // Time step (initial if adaptive)[s]
    DefineConstant [writeInterval = dt]; // Time interval between two successive output file saves [s]
    DefineConstant [dt_max = dt]; // Maximum allowed time step [s]
    DefineConstant [iter_max = 100]; // Maximum number of nonlinear iterations
    DefineConstant [extrapolationOrder = 2]; // Extrapolation order
    DefineConstant [tol_energy = 1e-6]; // Relative tolerance on the energy estimates

    // Control points
    controlPoint1 = {-r_wire/2+1e-5,0, 0}; // CP1
    controlPoint2 = {r_wire/2-1e-5, 0, 0}; // CP2
    controlPoint3 = {0, 0, -h_wire/2-1e-5}; // CP3
    controlPoint4 = {0, 0, h_wire/2+1e-5}; // CP4
    DefineConstant [savedPoints = 500]; // Resolution of the line saving postprocessing
}

Include "../lib/lawsAndFunctions.pro";

Function{
    // Sine source field
    controlTimeInstants = {timeFinalSimu, 1/(2*f), 1/f, 3/(2*f), 2*timeFinal};
    I[] = Imax * Sin[2.0 * Pi * f * $Time];
    hsVal[] = 1/mu0 * bmax * Sin[2.0 * Pi * f * $Time];
    // For the t-a-formulation
    thickness[Cond] = w_wire;
    thickness[Edge1] = w_wire;
    thickness[Air] = w_wire; // Fix me, doesn't make sense to define it here...

    directionApplied[] = Vector[0., 1., 0.];
}

Constraint {
    { Name a ;
        Case {
            If(SourceType == 0)
                {Region SurfOut ; Value 0.0;}
            ElseIf(SourceType == 1)
                // Nothing, the boundary condition is imposed via a surface term in the weak formulation
            EndIf
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
                EndIf
            Else
                // a-formulation and BF_RegionZ
                If(SourceType == 0)
                    If(Dim == 2)
                        { Region Cond; Value 1.0; TimeFunction I[]; }
                    Else
                        // { Region Electrode1; Value  1.0; TimeFunction I[]; } // Not ready for this model
                    EndIf
                EndIf
            ElseIf(formulation == ta_formulation)
                // t-a-formulation
                If(SourceType == 0)
                    { Region Edge1; Value 1.0; TimeFunction I[]; } // t_tilde = w t
                EndIf
            EndIf
        }
    }
    { Name Voltage ; Case {
        If(formulation == h_formulation || formulation == coupled_formulation || formulation == h_phi_ts_formulation)
            // h-formulation and cuts
            If(SourceType == 1)
                { Region Cuts; Value 0; }
            EndIf
        Else
            // a-formulation and BF_RegionZ
            If(SourceType == 1)
                // { Region Electrode1; Value 0.0; } // Not ready for this model
            EndIf
        ElseIf(formulation == ta_formulation)
            // t-a-formulation and edges
            If(SourceType == 1)
                { Region Edge1; Value 0.0; }
            EndIf
        EndIf
        }
    }
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

                If(formulation == ta_formulation)
                    Print[ h, OnElementsOf OmegaCC , File "res/h.pos", Name "h [A/m]" ];
                    Print[ b, OnElementsOf OmegaCC , File "res/b.pos", Name "b [T]" ];
                ElseIf(formulation == h_phi_ts_formulation)
                    Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h [A/m]" ];
                    Print[ b, OnElementsOf Air , File "res/b.pos", Name "b [T]" ];
                Else
                    Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h [A/m]" ];
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
