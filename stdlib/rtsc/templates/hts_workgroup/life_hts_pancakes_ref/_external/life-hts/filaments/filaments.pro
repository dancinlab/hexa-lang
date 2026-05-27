Include "filaments_data.pro";
Include "../lib/commonInformation.pro";

Group {
    // ------- PROBLEM DEFINITION -------
    // Dimension of the problem
    Dim = 2+ThreeD;

    // Excitation type of the system (for the boundary conditions)
    // 0: External applied field
    // 1: Imposed current intensity
    // 3: Both applied field and current intensity
    SourceType = 1;

    // Material type of region MATERIAL, 1: super, 2: copper
    MaterialType = 1;
    Flag_twist = 1; // Helicoidal Jacobian method (specific formulation)
    Flag_links = 0*(1-Flag_twist)*(1-ThreeD); // Thitipong method (specific formulation)
    Flag_cohomology = 1;
    Flag_cuts = (SourceType == 1); // Do we need cuts? (if no, meshing is simplified (no periodic cohomology))
    Flag_spurious_conductivity = 0;
    Flag_curlFree = 1; // Curl-free mixing of modes for k>0, or spurious conductivity (for perpendicular component only)


    // Number of modes = 2*k_max + 1
    k_max = (SourceType == 0) ? 1 : 0;

    // Test name - for output files
    // (directory name for .txt files, not .pos files)
    name = "filaments";
    //DefineConstant [testname = "cond_mat_new_3D_structured_prisms_1p1_super_new"];
    DefineConstant [testname = "test"];
    // ------- WEAK FORMULATION -------
    // Choice of the formulation
    formulation = (Flag_TA == 0) ? h_formulation + Flag_twist*(1-ThreeD) + 2*Flag_links : ta_formulation;

    // ------- Definition of the physical regions -------
    // Filling the regions
    Air = Region[ AIR ];
    Air += Region[ INF ];
    Matrix = Region[MATRIX];
    BndMatrix = Region[BND_MATRIX];
    IsThereFerro = 0; // Will be updated below if necessary
    IsThereSuper = 0; // Will be updated below if necessary
    Flag_Hysteresis = 0; // Will be updated below if necessary
    Flag_LinearProblem = 1; // Will be updated below if necessary

    NumFilamentsTotal = (Preset == 2) ? 6 : ((Preset == 7) ? 7 : 3);

    Filaments = Region[{}];
    BndFilaments = Region[{}];
    BndFilamentsTop = Region[{}];
    BndFilamentsBottom = Region[{}];
    For i In {1:NumLayers}
      For j In {1:NumFilaments~{i}}
        Filaments += Region[(FILAMENT + 1000 * i + j)];
        If(Flag_TA == 0)
            BndFilaments += Region[(BND_FILAMENT + 1200 * i + j)];
        Else
            PositiveEdge~{j} = Region[(BND_FILAMENT + 1200 * i + j)];
            NegativeEdge~{j} = Region[(BND_FILAMENT + 1250 * i + j)];
        EndIf
        BndFilamentsTop += Region[(BND_FILAMENT + 1100 * i + j)];
        BndFilamentsBottom += Region[(BND_FILAMENT + 1000 * i + j)];
      EndFor
    EndFor
    ArbitraryPoint = Region[ARBITRARY_POINT];
    DefineGroup[CondMatrix];
    If(ConductingMatrix)
        CondMatrix = Region[{Matrix}]; // conducting domain
        BndOmegaC = Region[BndMatrix]; // boundary of conducting domain
        //BndOmegaC += Region[{(BND_MATRIX + 1), (BND_MATRIX + 2)}];
        If(Flag_cuts)
            Cut = Region[(INF + 1)]; // thick cut
            Cuts = Region[ {Cut} ];
        EndIf
    Else
      Air += Region[{Matrix}]; // non-conducting domain
      If(Flag_TA == 1)
        BndOmegaC = Region[Filaments]; // boundary of conducting domain
      Else
        BndOmegaC = Region[BndFilaments]; // boundary of conducting domain
      EndIf
      If(TwistFraction != 1 && ThreeD && Flag_cuts) // With periodicity such that there is only one cut! (not general)
          Cut = Region[(INF + 1)]; // thick cut
          Cuts = Region[ {Cut} ];
      ElseIf(Flag_cuts)
          For j In {1:NumFilamentsTotal}
            Cut~{j} = Region[(INF + NumFilamentsTotal*2 + j)]; // FIXME: handle multiple cuts if multiple filaments
            Cuts += Region[{Cut~{j}}];
          EndFor
      EndIf
    EndIf
    If(ThreeD && Flag_cuts)
        Cut_axial = Region[(INF + 2)];
        Cuts += Region[ {Cut_axial} ];
    EndIf

    If(MaterialType == 1)
        Super += Region[ {Filaments} ];
        //Cond1 = Region[ {Filaments} ];
        IsThereSuper = 1;
        Flag_LinearProblem = 0;
    ElseIf(MaterialType == 2)
        Copper += Region[ {Filaments} ];
        //Cond1 = Region[ {Filaments} ];
    EndIf

    If(Flag_TA == 1)
        LateralEdges = Region[ {PositiveEdge_1, PositiveEdge_2, PositiveEdge_3,
            NegativeEdge_1, NegativeEdge_2, NegativeEdge_3} ];
        PositiveEdges = Region[ {PositiveEdge_1, PositiveEdge_2, PositiveEdge_3} ];
    EndIf

    SurfOut = Region[ BND_INF ];
    // Remaining regions
    If(Flag_spurious_conductivity == 0)
        LinOmegaC = Region[ {Copper, CondMatrix} ];
        OmegaCC = Region[ {Air} ];
    Else
        LinOmegaC = Region[ {Air, Copper, CondMatrix} ];
        Cuts = Region[ {} ];
        OmegaCC = Region[ {} ];
        BndOmegaC = Region[ {} ];
    EndIf
    NonLinOmegaC = Region[ {Super} ];
    OmegaC = Region[ {LinOmegaC, NonLinOmegaC} ];
    Omega = Region[ {OmegaC, OmegaCC} ];
    MagnLinDomain = Region[ {Air, Super, Copper, CondMatrix} ];

    OmegaCC_AndBnd = Region[{OmegaCC, BndOmegaC}];

    // Boundaries
    BndMatrixBottom = Region[(BND_MATRIX + 1)];
    BndMatrixTop = Region[(BND_MATRIX + 2)];
    BndAirBottom = Region[(BND_AIR + 1)];
    BndAirTop = Region[(BND_AIR + 2)];
    BndInfBottom = Region[(BND_INF + 1)];
    BndInfTop = Region[(BND_INF + 2)];

    SurfSym_slave = Region[{BndFilamentsTop, BndMatrixTop, BndAirTop, BndInfTop}];
    SurfSym_master = Region[{BndFilamentsBottom, BndMatrixBottom, BndAirBottom, BndInfBottom}];

    If(Flag_TA == 1)
        Gamma_e = Region[{SurfOut, SurfSym_slave, SurfSym_master}];
        Gamma_h = Region[{}];
    Else
        Gamma_h = Region[{SurfOut}];
        Gamma_e = Region[{}];
    EndIf
    GammaAll = Region[ {Gamma_h, Gamma_e} ];
}
// Circuit
Group{
    R1 = Region[{4000001}];
    Domain_Cir = Region[{R1}];
}
Function {
    Resistance[R1] = 1e-3 ;
}


Function{
    // ------- PARAMETERS -------
    // Superconductor parameters
    DefineConstant [jc = 7e9];//(Preset == 2) ? 1e8 : 3e10]; // Critical current density [A/m2]
    DefineConstant [n = 50]; // Superconductor exponent (n) value [-]
    // Excitation - Source field or imposed current intensty
    // 0: sine, 1: triangle, 2: up-down-pause, 3: step, 4: up-pause-down
    DefineConstant [Flag_Source = 1];
    DefineConstant [Imax = (Preset == 2) ? geoFactor*geoFactor*2.30907e-4*jc*0.5 : 0.8*jc*FilamentThickness*FilamentWidth];// /Sqrt[1+Flag_twist*(2*Pi/TwistPitch)^2*LayerRadius_1^2]]; // Maximum imposed current intensity [A]
    DefineConstant [f = 100]; // Frequency of imposed current intensity [Hz]
    DefineConstant [bmax = 1.912]; // Maximum applied magnetic induction [T]
    DefineConstant [timeStart = 0]; // Initial time [s]
    DefineConstant [timeFinal = 1]; // Final time for source definition [s]
    DefineConstant [timeFinalSimu = 1.25*120./(120*f)];//5./(4*f)]; // Final time of simulation [s]

    // ------- NUMERICAL PARAMETERS -------
    DefineConstant [dt = 2./(120*f)]; // Time step (initial if adaptive)[s]
    DefineConstant [dt_max = dt]; // Maximum allowed time step [s]
    DefineConstant [iter_max = 600]; // Maximum number of nonlinear iterations
    DefineConstant [extrapolationOrder = 1]; // Extrapolation order
    DefineConstant [tol_energy = 1e-6]; // Relative tolerance on the energy estimates
    // Output information
    economPos = 0; // 0: Saves all fields. 1: Does not save fields (.pos)
    // Parameters
    DefineConstant [writeInterval = dt]; // Time interval between two successive output file saves [s]
    DefineConstant [savedPoints = 200]; // Resolution of the line saving postprocessing
    // Control points
    controlPoint1 = {0 ,0, 0.05*geoFactor}; // CP1
    controlPoint2 = {AirRadius-1e-5*geoFactor, 0, 0.05*geoFactor}; // CP2
    controlPoint5 = {0 ,0, 0}; // CP1
    controlPoint6 = {AirRadius-1e-5*geoFactor, 0, 0}; // CP2
    controlPoint3 = {0, AirRadius/2+2e-3*geoFactor, 0}; // CP3
    controlPoint4 = {AirRadius/2, AirRadius/2+2e-3*geoFactor, 0}; // CP4


}

Include "../lib/lawsAndFunctions.pro";

Function{
    // Air
    mu[CondMatrix] = mu0;
    nu[CondMatrix] = nu0;
    // Copper
    rho[CondMatrix] = 1e-8;//1.81e-10;//100*rho_copper[];//
    sigma[CondMatrix] = 1./rho[];
    // If spurious sigma
    If(Flag_spurious_conductivity == 1 || Flag_curlFree == 0)
        spuriousResistivity = 1e1;
        rho[Air] = spuriousResistivity;
        spuriousConductivity = 1;
        sigma[Air] = spuriousConductivity;
    EndIf

    If(Flag_Source == 0)
        // TBC...
    ElseIf(Flag_Source == 1)
        controlTimeInstants = {timeFinalSimu, 2*timeFinalSimu};
        I_tot[] = -Imax * Sin[2*Pi*f * $Time] ;
        hsVal[] = nu0*bmax * Sin[2*Pi*f * $Time] ;
    ElseIf(Flag_Source == 4)
        // TBC...
    EndIf
    // Direction of applied field
    directionApplied[] = Vector[0., 1., 0.];

    // Helicoidal transformation
    p = TwistPitch;
    alpha = Flag_twist*2*Pi/p;
    x_to_xi[] = Vector[(X[]*Cos[alpha*Z[]]+Y[]*Sin[alpha*Z[]]), (-X[]*Sin[alpha*Z[]]+Y[]*Cos[alpha*Z[]]), Z[]];
    xi_to_x[] = Vector[(X[]*Cos[alpha*Z[]]-Y[]*Sin[alpha*Z[]]), (X[]*Sin[alpha*Z[]]+Y[]*Cos[alpha*Z[]]), Z[]];
    // For rotation tensor and concise formulation of C.C tensor
    r[] = Norm[XYZ[]];
    phi[] = Atan2[Y[], X[]];

    // $T^{-1}$ for twist
    Tinv[] = Rotate[
        TensorSym[ 1., 0, 0, 1.+ alpha*alpha*r[]*r[], -alpha*r[], 1.],
        0, 0, -phi[]]; // rotate tensor around z-axis
    T[] = Rotate[
        TensorSym[ 1, 0, 0, 1, alpha*r[], 1+alpha*alpha*r[]*r[]],
        0, 0, -phi[]];
    Jinvtrans[] = Tensor[1, 0, 0, 0, 1, 0, alpha*Y[], -alpha*X[], 1]; // On z=0 !!
    J[] = Tensor[1, 0, -alpha*Y[], 0, 1, alpha*X[], 0, 0, 1]; // On z=0 !!
    Jtrans[] = Tensor[1, 0, 0, 0, 1, 0, -alpha*Y[], alpha*X[], 1]; // On z=0 !!
    JtransFull[] = Tensor[Cos[alpha*Z[]], Sin[alpha*Z[]], 0,
                        -Sin[alpha*Z[]], Cos[alpha*Z[]], 0,
                        -alpha*Y[], alpha*X[], 1]; // In terms of x,y,z!!
    // Anisotropic tensors
    mu_tilde[] = mu[] * Tinv[];
    rho_tilde[] = rho[] * T[];

    // For TA-formulation
    thickness[] = FilamentThickness;

    // Post-pro (b and j along a fiber)
    R_sample = LayerRadius_1+FilamentRadius*0.8;
    phi0 = 0*Pi/50;

}

Constraint {
    { Name phi ;
        Case {
            If(SourceType == 1)
                {Region ArbitraryPoint ; Value 0.0 ;}
            ElseIf(SourceType == 0)
                {Region SurfOut ; Value XYZ[]*directionApplied[] ; TimeFunction hsVal[] ;}
            EndIf
            If(ThreeD)
                { Region SurfSym_slave ; Type Link ; RegionRef SurfSym_master;
                    Coefficient  1.0;
                    Function Vector[$X, $Y, 0] ;
          	        //Function Vector[($X*Cos[alpha*$Z]+$Y*Sin[alpha*$Z]), (-$X*Sin[alpha*$Z]+$Y*Cos[alpha*$Z]),0] ;
                }
            EndIf
        }
    }
    { Name h_perp ;
        Case {
             // {Region SurfOut ; Value 1.0 ; TimeFunction I_tot[]*alpha/(2*Pi) ;}
              { Region OmegaCC_AndBnd; Value 1.0; TimeFunction -I_tot[]*alpha/(2*Pi) ;}
        }
    }
    If(k_max >= 1)
        For k In {1:k_max}
            { Name phi_m~{k} ;
                Case {
                    {Region SurfOut ; Value Sqrt[2]/2*Y[] ; TimeFunction hsVal[] ;}
                }
            }
            { Name phi_p~{k} ;
                Case {
                    {Region SurfOut ; Value Sqrt[2]/2*X[] ; TimeFunction hsVal[] ;}
                }
            }
            { Name h_perp_m~{k} ;
                Case {
                    {Region SurfOut ; Value alpha*Sqrt[2]/2*X[] ; TimeFunction hsVal[] ;}
                }
            }
            { Name h_perp_p~{k} ;
                Case {
                    {Region SurfOut ; Value -alpha*Sqrt[2]/2*Y[] ; TimeFunction hsVal[] ;}
                }
            }
        EndFor
    EndIf
    { Name lagrangeMult ;
        Case {
            {Region SurfOut ; Value 0.0 ;}
        }
    }
    { Name a ;
        Case {
            {Region GammaAll ; Value 0.0 ;}
        }
    }
    { Name h ;
        Case {
            // {Region SurfOut ; Value 0.0 ; TimeFunction hsVal[] ;}
            If(ThreeD)
                { Region SurfSym_slave ; Type Link ; RegionRef SurfSym_master;
                    Coefficient  1.0;
                    Function Vector[$X, $Y, 0] ;
                    //Function Vector[($X*Cos[alpha*$Z]+$Y*Sin[alpha*$Z]), (-$X*Sin[alpha*$Z]+$Y*Cos[alpha*$Z]),0] ;
                }// */
            EndIf
        }
    }
    { Name phi_tmp ;
        Case {
            // {Region SurfOut ; Value XYZ[]*directionApplied[] ; TimeFunction hsVal[] ;}
        }
    }
    { Name Current ;
        Case {
            If(formulation == h_formulation || formulation == h_formulation+1 || formulation == h_formulation+2 || formulation == coupled_formulation)
                // h-formulation and cuts
                If(Flag_cuts && (ConductingMatrix == 1 || (TwistFraction != 1 && ThreeD)) )
                    { Region Cut; Value SourceType; TimeFunction I_tot[] ;}
                ElseIf(Flag_cuts)
                    { Region Cut_1; Value SourceType; TimeFunction I_tot[] ;}
                    { Region Cut_2; Value SourceType; TimeFunction I_tot[] ;}
                    { Region Cut_3; Value SourceType; TimeFunction I_tot[] ;}
                    { Region Cut_4; Value SourceType; TimeFunction I_tot[] ;}
                    { Region Cut_5; Value SourceType; TimeFunction I_tot[] ;}
                    { Region Cut_6; Value SourceType; TimeFunction I_tot[] ;}
                    // { Region Cut_7; Value SourceType; TimeFunction 0*I_tot[] ;}// */
                EndIf
                If(ThreeD && Flag_cuts)
                    { Region Cut_axial; Value SourceType; TimeFunction 0*I_tot[] ;} // For an axial field (to add in the source type)
                EndIf
            ElseIf(formulation == ta_formulation)
                { Region PositiveEdge_1; Value SourceType; TimeFunction -I_tot[] ;}
                { Region PositiveEdge_2; Value SourceType; TimeFunction -I_tot[] ;}
                { Region PositiveEdge_3; Value SourceType; TimeFunction -I_tot[] ;}
            EndIf
        }
    }
    { Name Voltage ;
        Case {
            /*{ Region Cut_1; Value SourceType; TimeFunction I_tot[] ;}
            { Region Cut_2; Value SourceType; TimeFunction I_tot[] ;}
            { Region Cut_3; Value SourceType; TimeFunction I_tot[] ;}
            { Region Cut_4; Value SourceType; TimeFunction I_tot[] ;}
            { Region Cut_5; Value SourceType; TimeFunction I_tot[] ;}
            { Region Cut_6; Value SourceType; TimeFunction I_tot[] ;}*/
        }
    }
}

Include "../lib/jac_int.pro";
Include "../lib/formulations.pro";
Include "../lib/advanced_formulations.pro";
Include "../lib/resolution.pro";

Function{
    DefineConstant [outputMagInduction2_sin = StrCat[outputDirectory,"/bLine2_sin.txt"]];
}
PostOperation {
    { Name HelicalTransfo; NameOfPostProcessing HelicalTransfo;
        Operation{
            Print[ h_transformed, OnElementsOf Omega , File "res/h_transformed.pos", Name "h_transformed" ];
        }
    }
    { Name MagDyn; // LastTimeStepOnly 0 ;
        If(formulation == h_formulation)
            NameOfPostProcessing MagDyn_htot;
        ElseIf(formulation == h_formulation+1)
            NameOfPostProcessing MagDyn_htot_full;
        ElseIf(formulation == h_formulation+2)
            NameOfPostProcessing MagDyn_htot_links;
        ElseIf(formulation == a_formulation)
            NameOfPostProcessing MagDyn_avtot;
        ElseIf(formulation == ta_formulation)
            NameOfPostProcessing MagDyn_ta;
        ElseIf(formulation == coupled_formulation)
            NameOfPostProcessing MagDyn_coupled;
        EndIf
        Operation {
            If(economPos == 0)
                If(formulation == h_formulation || formulation == h_formulation+1)
                    Print[ phi, OnElementsOf Omega , File "res/phi.pos", Name "phi [A]" ];
                ElseIf(formulation == a_formulation)
                    Print[ a, OnElementsOf Omega , File "res/a.pos", Name "a [Tm]" ];
                    Print[ ur, OnElementsOf OmegaC , File "res/ur.pos", Name "ur [V/m]" ];
                ElseIf(formulation == ta_formulation)
                    Print[ a, OnElementsOf Omega , File "res/a.pos", Name "a [Tm]" ];
                    Print[ t, OnElementsOf OmegaC , File "res/t.pos", Name "t [A/m]" ];
                EndIf
                Print[ j, OnElementsOf OmegaC , File "res/j.pos", Name "j [A/m2]" ];
                //Print[ jouleLosses, OnElementsOf OmegaC , File "res/jouleLosses.pos", Name "jouleLosses [W/m3]" ];
                //Print[ jouleLosses, OnPlane{{LayerRadius_1-FilamentRadius, -FilamentRadius, 0}{LayerRadius_1+FilamentRadius, -FilamentRadius, 0}{LayerRadius_1-FilamentRadius, FilamentRadius, 0}}{200, 200},
                //    File "res/jouleLosses_plane.pos"];
                //Print[ norm_j, OnElementsOf OmegaC , File "res/j_norm.pos", Name "j_norm [A/m2]" ];
                //Print[ ez, OnElementsOf OmegaC , File "res/ez.pos", Name "e [V/m]" ];
                //Print[ hy, OnElementsOf OmegaC , File "res/hy.pos", Name "h [A/m]" ];
                //Print[ e, OnElementsOf OmegaC , File "res/e.pos", Name "e [V/m]" ];
                If(formulation == ta_formulation)
                    Print[ h, OnElementsOf OmegaCC , File "res/h.pos", Name "h(x) [A/m]" ];
                    Print[ b, OnElementsOf OmegaCC , File "res/b.pos", Name "b [T]" ];
                Else
                    Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h(x) [A/m]" ];
                    //Print[ h_sin, OnElementsOf Omega , File "res/h_sin.pos", Name "h(x) [A/m]" ];
                    Print[ b, OnElementsOf Omega , File "res/b.pos", Name "b [T]" ];
                    //Print[ b_sin, OnElementsOf Omega , File "res/b_sin.pos", Name "b_sin [T]" ];
                    Print[ bz, OnElementsOf Omega , File "res/bz.pos", Name "bz [T]" ];
                    //Print[ b_sinz, OnElementsOf Omega , File "res/b_sinz.pos", Name "b_sinz [T]" ];
                    //Print[ bplane, OnElementsOf Omega , File "res/bplane.pos", Name "bplane [T]" ];
                    Print[ jz, OnElementsOf NonLinOmegaC , File "res/jz.pos", Name "j [A/m2]" ];
                    //Print[ jplane, OnElementsOf OmegaC , File "res/jplane.pos", Name "jplane [A/m2]" ];
                EndIf
                //Print[ bz, OnElementsOf Omega , File "res/bz.pos", Name "bz [T]" ];
                //Print[ bplane, OnElementsOf Omega , File "res/bplane.pos", Name "bplane [sT]" ];
                If(ThreeD == 0 && Flag_twist)
                    //Print[ j_xi, OnElementsOf OmegaC , File "res/j_xi.pos", Name "j(xi) [A/m2]" ];
                    //Print[ h_xi, OnElementsOf Omega , File "res/h_xi.pos", Name "h(xi) [A/m]" ];
                    //Print[ hp_xi, OnElementsOf Omega , File "res/hp_xi.pos", Name "hp(xi) [A/m]" ];
                    //Print[ phi_12_p_xi, OnElementsOf Omega , File "res/phi_12_p_xi.pos", Name "phi_12_p(xi) [A/m]" ];
                    //Print[ phi_12_m_xi, OnElementsOf Omega , File "res/phi_12_m_xi.pos", Name "phi_12_m(xi) [A/m]" ];
                    //Print[ h_3_m_xi, OnElementsOf Omega , File "res/h_3_m_xi.pos", Name "h_3_m(xi) [A/m]" ];
                    //Print[ h_3_p_xi, OnElementsOf Omega , File "res/h_3_p_xi.pos", Name "h_3_p(xi) [A/m]" ];                    //Print[ h_12_x, OnElementsOf Omega , File "res/h_12_x.pos", Name "h_12(x) [A/m]" ];
                    //Print[ h_3_x, OnElementsOf Omega , File "res/h_3_x.pos", Name "h_3(x) [A/m]" ];
                    //Print[ h_12_xi, OnElementsOf Omega , File "res/h_12_xi.pos", Name "h_12(xi) [A/m]" ];
                    //Print[ h_3_xi, OnElementsOf Omega , File "res/h_3_xi.pos", Name "h_3(xi) [A/m]" ];
                    //Print[ h_xi, OnElementsOf Omega , File "res/h_xi.pos", Name "h_xi(x) [A/m]", LastTimeStepOnly ]; // For visualization and change of coordinates
                EndIf
            EndIf
            //Print[ b, OnPlane{{0, 0, 0}{W/2, 0, 0}{0, H_cylinder/2, 0}}{100, 100},
            //    File "res/b_onPlane.pos"];
            Print[ j, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                Format TimeTable, File outputCurrent];
            If(ThreeD == 0)
                Print[ b, OnLine{{List[controlPoint5]}{List[controlPoint6]}} {savedPoints},
                    Format TimeTable, File outputMagInduction1];
                Print[ h, OnLine{{List[controlPoint5]}{List[controlPoint6]}} {savedPoints},
                    Format TimeTable, File outputMagField1];
                //Print[ b_sin, OnLine{{List[controlPoint5]}{List[controlPoint6]}} {savedPoints},
                //    Format TimeTable, File outputMagInduction2_sin];
            Else
                //Print[ b, OnLine{{List[controlPoint5]}{List[controlPoint6]}} {savedPoints},
                //    Format TimeTable, File outputMagInduction1];
                Print[ h, OnLine{{List[controlPoint5]}{List[controlPoint6]}} {savedPoints},
                    Format TimeTable, File outputMagField1];
                // Sampling on a constant xi_1,xi_2 curve (upwards)
                Print[ b, OnGrid{R_sample*Cos[phi0+alpha*$A], R_sample*Sin[phi0+alpha*$A], $A}{ 0:TwistPitch*TwistFraction:TwistPitch*TwistFraction/50, 0, 0 },
                    Format TimeTable, File outputMagInduction1];
                For filament In {1:5}
                    Print[ b, OnGrid{R_sample*Cos[phi0+filament*Pi/3+alpha*$A], R_sample*Sin[phi0+filament*Pi/3+alpha*$A], $A}{ 0:TwistPitch*TwistFraction:TwistPitch*TwistFraction/50, 0, 0 },
                        Format TimeTable, File > outputMagInduction1];
                EndFor
                Print[ j, OnGrid{R_sample*Cos[phi0+alpha*$A], R_sample*Sin[phi0+alpha*$A], $A}{ 0:TwistPitch*TwistFraction:TwistPitch*TwistFraction/50, 0, 0 },
                    Format TimeTable, File outputCurrent];
                For filament In {1:5}
                    Print[ j, OnGrid{R_sample*Cos[phi0+filament*Pi/3+alpha*$A], R_sample*Sin[phi0+filament*Pi/3+alpha*$A], $A}{ 0:TwistPitch*TwistFraction:TwistPitch*TwistFraction/50, 0, 0 },
                        Format TimeTable, File > outputCurrent];
                EndFor
            EndIf
            //Print[ h, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
            //    Format TimeTable, File outputMagField1];
            Print[ b, OnLine{{List[controlPoint5]}{List[controlPoint6]}} {savedPoints},
                Format TimeTable, File outputMagInduction2];
            //Print[ dissPowerCut[OmegaC], OnGlobal, Format Table, File "res/powerTA.txt"];
            Print[ hsVal[Omega], OnRegion Omega, Format TimeTable, File outputAppliedField];
            //Print[ normal, OnElementsOf OmegaC, File "res/normal.pos", Name "h(xi) [A/m]" ];
        }
    }
}

DefineConstant[
  R_ = {"MagDyn", Name "GetDP/1ResolutionChoices", Visible 0},
  C_ = {"-solve -pos -bin -v 3 -v2", Name "GetDP/9ComputeCommand", Visible 0},
  P_ = { "MagDyn", Name "GetDP/2PostOperationChoices", Visible 0}
];
