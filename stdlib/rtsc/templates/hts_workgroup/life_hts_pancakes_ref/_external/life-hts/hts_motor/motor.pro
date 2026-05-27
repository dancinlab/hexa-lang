Include "motor_data.pro";
Include "../lib/commonInformation.pro";

Group {
    // Output choice
    DefineConstant[onelabInterface = {1, Choices{0,1}, Name "Input/3Problem/2Get solution during simulation?"}]; // Set to 0 for launching in terminal (faster)
    realTimeInfo = 1;
    realTimeSolution = onelabInterface;

    // ------- PROBLEM DEFINITION -------
    // Test name - for output files
    name = "hts_motor";
    // Directory name for additional output .txt files
    testname = "motor_model";
    // Dimension of the problem
    Dim = 2;
    // Is there a moving band in the problem? Is the rotor rotating?
    Flag_MB = 1;
    Flag_rotating = (preset >= 3) ? 0 : 1;

    // ------- WEAK FORMULATION -------
    // Choice of the formulation
    formulation = (preset>=3) ? coupled_formulation : a_formulation;

    // ------- Definition of the physical regions -------
    // Filling the regions
    Rotor_Air = Region[ ROTOR_AIR ];
    Stator_Airgap = Region[ STATOR_AIR_GAP ]; // Only for torque computation
    Stator_Air = Region[ STATOR_AIR ];
    Stator_Air += Region[ {Stator_Airgap}];
    DefineGroup [Cut1, Cut2, Iron];
    IsThereFerro = nonlinferro;
    IsThereSuper = (preset >= 3) ? 1 : 0;
    If(preset >= 3)
        BndOmegaC += Region[ ROTOR_MAGNET_BND ];
        BndOmegaC_side += Region[ ROTOR_MAGNET_BND_SIDE ];
        BndOmegaC += Region[ (ROTOR_MAGNET_BND+1) ];
        BndOmegaC_side += Region[ (ROTOR_MAGNET_BND_SIDE+1) ];
    EndIf
    Magnet1 += Region[ ROTOR_MAGNET ];
    Magnet2 += Region[ (ROTOR_MAGNET+1) ];
    If(preset >= 3)
        Super += Region[ {Magnet1, Magnet2} ];
        Cut1 = Region[ CUT ];
        Cut2 = Region[ (CUT+1) ];
    EndIf

    Rotor_Iron += Region[ ROTOR_IRON ];
    Stator_Iron += Region[ STATOR_IRON ];
    Iron += Region[ {Rotor_Iron, Stator_Iron} ];

    B_p = Region[ STATOR_INDUCTOR ];
    A_m = Region[ (STATOR_INDUCTOR+1) ];
    C_p = Region[ (STATOR_INDUCTOR+2) ];
    B_m = Region[ (STATOR_INDUCTOR+3) ];
    A_p = Region[ (STATOR_INDUCTOR+4) ];
    C_m = Region[ (STATOR_INDUCTOR+5) ];

    Air += Region[{Rotor_Air, Stator_Air}];

    SurfOut = Region[ ROTOR_BND_IN ];
    SurfOut += Region[ STATOR_BND_OUT ];

    SurfSym_master = Region[ ROTOR_BND_A0 ];
    SurfSym_slave = Region[ ROTOR_BND_A5 ];
    SurfSym_master += Region[ STATOR_BND_T0 ];
    SurfSym_slave += Region[ STATOR_BND_T13 ];

    SurfSym = Region[{SurfSym_master, SurfSym_slave}];
    // Moving band to account for symmetry
    Stator_Bnd_MB = Region[STATOR_BND_MOVING_BAND];
    For k In {1:p}
      Rotor_Bnd_MB~{k} = Region[ (ROTOR_BND_MOVING_BAND+k-1) ];
      Rotor_Bnd_MB += Region[ Rotor_Bnd_MB~{k} ];
    EndFor
    Rotor_Bnd_MBaux = Region[ {Rotor_Bnd_MB, -Rotor_Bnd_MB~{1}}];
    MovingBand_PhysicalNb = Region[0] ;
    Rotor_Moving = Region[{Rotor_Air, Rotor_Iron, Magnet1, Magnet2, Rotor_Bnd_MBaux} ] ;
    MB  = MovingBand2D[ MovingBand_PhysicalNb, Stator_Bnd_MB, Rotor_Bnd_MB, p] ;
    Air += Region[{MB}];
    // Remaining regions
    OmegaC_stranded += Region[ { A_p, A_m, B_p, B_m, C_p, C_m} ];
    If(preset < 3)
        OmegaC_stranded += Region[ {Magnet1, Magnet2} ];
    EndIf
    NonLinOmegaC = Region[ {Super} ];
    OmegaC = Region[ {LinOmegaC, NonLinOmegaC} ];
    Cuts = Region[ {Cut1, Cut2} ];
    OmegaCC = Region[ {Air, Iron, OmegaC_stranded} ];
    Omega = Region[ {OmegaC, OmegaCC} ];
    MagnLinDomain = Region[ {Air, LinOmegaC, NonLinOmegaC, OmegaC_stranded} ];
    If(nonlinferro == 0)
        MagnLinDomain += Region[ {Iron} ];
    Else
        MagnAnhyDomain += Region[ {Iron} ];
    EndIf

    If(formulation == h_formulation)
        Gamma_h = Region[{SurfOut}];
        Gamma_e = Region[{SurfSym}];
    ElseIf(formulation == a_formulation)
        Gamma_h = Region[{SurfSym}];
        Gamma_e = Region[{SurfOut}];
    ElseIf(formulation == coupled_formulation)
        Gamma_h = Region[{}];
        Gamma_e = Region[{SurfOut, SurfSym}];
    EndIf
    GammaAll = Region[ {Gamma_h, Gamma_e} ];

}

Function{
    // ------- PARAMETERS -------
    // Superconductor parameters
    DefineConstant [jc = {1e8, Name "Input/4Material Properties/2jc (Am⁻²)"}]; // Critical current density [A/m2]
    DefineConstant [n = {20, Visible (preset >= 3), Name "Input/4Material Properties/1n (-)"}]; // Superconductor exponent (n) value [-]
    // Ferromagnetic material parameters
    DefineConstant [mur0 = {1700.0, Visible nonlinferro, Name "Input/4Material Properties/3mur at low fields (-)"}]; // Relative permeability at low fields [-]
    DefineConstant [m0 = {1.04e6,Visible nonlinferro, Name "Input/4Material Properties/4Saturation field (Am^-1)"}]; // Magnetic field at saturation [A/m]
    DefineConstant [mur = {1000.0, Visible !nonlinferro, Name "Input/4Material Properties/3mur for ferro (-)"}]; // Relative permeability for linear material [-]
    // Excitation - Source field or imposed current intensty
    // 0: sine, 1: triangle, 2: up-down-pause, 3: step, 4: up-pause-down
    DefineConstant [F = {0.9, Visible (preset==4), ReadOnly !expMode, Name "Input/3Problem/1Filling factor for current (-)"}]; // Relative permeability at low fields [-]
    DefineConstant [Imax = F*jc*R2*(A2-A1)*jcw]; // Maximum imposed current intensity [A]
    DefineConstant [f = (preset!=4) ? 250 : 50]; // Frequency of imposed current intensity [Hz]
    DefineConstant [t_pulse = 0.1];
    DefineConstant [amplitude = 25]; // Peak intensity relative to motor mode intensity
    DefineConstant [partLength = 5];
    DefineConstant [timeStart = 0]; // Initial time [s]
    DefineConstant [timeFinal = (preset == 3) ? t_pulse*5 : 5/(4*f)]; // Final time for source definition [s]
    DefineConstant [timeFinalSimu = timeFinal];//timeFinal]; // Final time of simulation [s]

    // ------- NUMERICAL PARAMETERS -------
    DefineConstant [dt = {(preset == 3) ? meshMult*t_pulse/300 : meshMult*timeFinal/(preset == 4 ? 1000:500), Highlight "LightBlue",
        ReadOnly !expMode, Name "Input/5Method/Time step (s)"}]; // Time step (initial if adaptive)[s]
    DefineConstant [adaptive = 1]; // Allow adaptive time step increase (case 0 not implemented yet)
    DefineConstant [dt_max = (preset==3)?4*dt:dt]; // Maximum allowed time step [s]
    DefineConstant [iter_max = (preset==3) ? 40 : 40]; // Maximum number of nonlinear iterations
    DefineConstant [extrapolationOrder = (preset>=3) ? 1 : 2]; // Extrapolation order
    DefineConstant [tol_energy = 1e-6]; // Relative tolerance on the energy estimates
    DefineConstant [writeInterval = (preset==3)?2*dt:dt]; // Time interval between two successive output file saves [s]
    // Control points (for output)
    controlPoint1 = {R1,0, 0}; // CP1
    controlPoint2 = {R6, 0, 0}; // CP2
    controlPoint3 = {0, 0, 0}; // CP3
    controlPoint4 = {R3, 0, 0}; // CP4
    DefineConstant [savedPoints = 200]; // Resolution of the line saving postprocessing

    For k In {1:savedPoints}
        circlePointX~{k} = (R3-eps) * Cos[k*2*Pi/(p*(savedPoints+1))];
        circlePointY~{k} = (R3-eps) * Sin[k*2*Pi/(p*(savedPoints+1))];
    EndFor

    // Imposed current densities
    pA = 0;
    pB = -2*Pi/3;
    pC = -4*Pi/3;
    jsStator = 10e6*Sqrt[2];
    DefineFunction [pulse, hsVal];
    If(preset == 1)
        js[A_p] = jsStator * F_Cos_wt_p[]{2*Pi*f, pA} * Vector[0, 0, 1];
        js[A_m] = -jsStator * F_Cos_wt_p[]{2*Pi*f, pA} * Vector[0, 0, 1];
        js[B_p] = jsStator * F_Cos_wt_p[]{2*Pi*f, pB} * Vector[0, 0, 1];
        js[B_m] = -jsStator * F_Cos_wt_p[]{2*Pi*f, pB} * Vector[0, 0, 1];
        js[C_p] = jsStator * F_Cos_wt_p[]{2*Pi*f, pC} * Vector[0, 0, 1];
        js[C_m] = -jsStator * F_Cos_wt_p[]{2*Pi*f, pC} * Vector[0, 0, 1];

        js[Magnet1] = jc * Vector[0, 0, 1];
        js[Magnet2] = -jc * Vector[0, 0, 1];
    ElseIf(preset == 2)
        js[A_p] = jsStator * Cos[pA] * Vector[0, 0, 1];
        js[A_m] = -jsStator * Cos[pA] * Vector[0, 0, 1];
        js[B_p] = jsStator * Cos[pB] * Vector[0, 0, 1];
        js[B_m] = -jsStator * Cos[pB] * Vector[0, 0, 1];
        js[C_p] = jsStator * Cos[pC] * Vector[0, 0, 1];
        js[C_m] = -jsStator * Cos[pC] * Vector[0, 0, 1];

        js[Magnet1] = jc * Vector[0, 0, 1];
        js[Magnet2] = -jc * Vector[0, 0, 1];
    ElseIf(preset == 3)
        pulse[] = jsStator * amplitude*$Time/t_pulse * Exp[1-$Time/t_pulse];
        js[B_p] = -pulse[] * Vector[0, 0, 1];
        js[A_m] = -0*pulse[] * Vector[0, 0, 1];
        js[C_p] = pulse[] * Vector[0, 0, 1];

        js[B_m] = pulse[] * Vector[0, 0, 1];
        js[A_p] = 0*pulse[] * Vector[0, 0, 1];
        js[C_m] = -pulse[] * Vector[0, 0, 1];
    ElseIf(preset == 4)
        js[B_p] = 0 * Vector[0, 0, 1];
        js[A_m] = 0 * Vector[0, 0, 1];
        js[C_p] = 0 * Vector[0, 0, 1];

        js[B_m] = 0 * Vector[0, 0, 1];
        js[A_p] = 0 * Vector[0, 0, 1];
        js[C_m] = 0 * Vector[0, 0, 1];

        I_imposed[] = Imax * Sin[2*Pi*f*$Time];
    EndIf

    // Rotation parameters/constants
    rpm = 60*f/p; // Turn per minute
    omega = 2*Pi*rpm/60; // Rotation speed (rad/s)
    delta_theta[] = $DTime * omega ;
    RotatePZ[] = Rotate[ Vector[$X,$Y,$Z], 0, 0, $1 ] ;
}

Include "../lib/lawsAndFunctions.pro";

Function{
    // Air and Super already OK

    // Iron
    If(nonlinferro == 0)
        mu[Iron] = mur*mu0;
        nu[Iron] = 1/mu[];
    Else
        mu[Iron] = mu_anhyModel[$1];
        dbdh[Iron] = dbdh_anhyModel[$1];
        nu[Iron] = nu_anhyModel[$1];
        dhdb[Iron] = dhdb_anhyModel[$1];
    EndIf
    // Stranded region
    mu[OmegaC_stranded] = mu0;
    nu[OmegaC_stranded] = 1/mu[];

}

// Only external field is implemented
Constraint {
    { Name a ;
        Case {
            {Region SurfOut ; Value 0 ;}
            {Region SurfSym_slave; Type Link;
                RegionRef SurfSym_master; Coefficient 1 ;
                Function RotatePZ[-2*Pi/p];
            }
            //For the moving band
            For k In {1:p-1}
            { Region Rotor_Bnd_MB~{k+1} ;
                SubRegion Rotor_Bnd_MB~{(k!=p-1)?k+2:1}; Type Link;
                RegionRef Rotor_Bnd_MB_1; SubRegionRef Rotor_Bnd_MB_2;
                Coefficient 1;
                Function RotatePZ[-k*2*Pi/p]; }
            EndFor
        }
    }
    { Name a2 ;
        Case {
            {Region Gamma_e ; Value 0.0 ;} // Second-order hierarchical elements
        }
    }
    { Name h ;
        Case {
        }
    }
    { Name j ;
        Case {
        }
    }
    { Name phi ;
        Case {
            { Region SurfSym_slave; Type Link;
                RegionRef SurfSym_master; Coefficient 1 ;
                Function RotatePZ[-2*Pi/p];
            }
            //For the moving band
            For k In {1:p-1}
            { Region Rotor_Bnd_MB~{k+1} ;
                SubRegion Rotor_Bnd_MB~{(k!=p-1)?k+2:1}; Type Link;
                RegionRef Rotor_Bnd_MB_1; SubRegionRef Rotor_Bnd_MB_2;
                Coefficient 1;
                Function RotatePZ[-k*2*Pi/p]; }
            EndFor
        }
    }
    { Name Current ; Type Assign;
        Case {
            If(formulation == h_formulation || formulation == coupled_formulation)
                // h-formulation and cuts
                If(preset != 4)
                    { Region Cut1; Value 0.0;}
                    { Region Cut2; Value 0.0;}
                Else
                    { Region Cut1; Value 1.0; TimeFunction I_imposed[];}
                    { Region Cut2; Value -1.0; TimeFunction I_imposed[];}
                EndIf
            Else
                // a-formulation and BF_RegionZ
                If(preset != 4)
                    { Region Magnet1; Value 0; }
                    { Region Magnet2; Value 0; }
                Else
                    { Region Magnet1; Value 1.0; TimeFunction I_imposed[];}
                    { Region Magnet2; Value -1.0; TimeFunction I_imposed[];}
                EndIf
            EndIf
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
            Print[ time_ms[Magnet1], OnRegion Magnet1, LastTimeStepOnly, Format Table, SendToServer "Output/0Time [ms]"] ;
            If(preset < 3)
                Print[ rotor_angle[Magnet1], OnRegion Magnet1, LastTimeStepOnly, Format Table, SendToServer "Output/0Rotor angle [deg]"] ;
                Print[ torqueMaxwell[Stator_Airgap], OnGlobal, Format Table,
                    LastTimeStepOnly, SendToServer "Output/3Torque [Nm]", Color "Ivory" ];
            ElseIf(preset == 3)
                Print[ js_value[B_m], OnRegion B_m, LastTimeStepOnly, Format Table, SendToServer "Output/3Source current density [Am-2]"] ;
                Print[ m_avg_x_tesla[Magnet1], OnRegion Magnet1, LastTimeStepOnly, Format Table, SendToServer "Output/4Magnetization along x [T]"] ;
                Print[ m_avg_y_tesla[Magnet1], OnRegion Magnet1, LastTimeStepOnly, Format Table, SendToServer "Output/4Magnetization along y [T]"] ;
                Print[ bx, OnPoint {0.2, 0.066, 0}, LastTimeStepOnly, Format Table, SendToServer "Output/5bx [T]"] ;
            Else
                Print[ I, OnRegion Cut1, LastTimeStepOnly, Format Table, SendToServer "Output/3Applied current [A]"] ;
                Print[ dissPower[Magnet1], OnGlobal, LastTimeStepOnly, Format Table, SendToServer "Output/3Joule loss in magnet 1 [W]"] ;
                Print[ dissPower[Magnet2], OnGlobal, LastTimeStepOnly, Format Table, SendToServer "Output/3Joule loss in magnet 2 [W]"] ;
            EndIf
        }
    }
    { Name MagDyn;
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
                    Print[ phi, OnElementsOf OmegaCC , File "res/phi.pos", Name "phi [A]", LastTimeStepOnly onelabInterface ];
                ElseIf(formulation == a_formulation)
                    Print[ az, OnElementsOf Omega , File "res/a.pos", Name "a [Tm]", LastTimeStepOnly onelabInterface];
                    Print[ ur, OnElementsOf OmegaC , File "res/ur.pos", Name "ur [V/m]", LastTimeStepOnly onelabInterface];
                    Print[ js, OnElementsOf OmegaC_stranded , File "res/js.pos", Name "js [A/m2]", LastTimeStepOnly onelabInterface];
                ElseIf(formulation == coupled_formulation)
                    Print[ a, OnElementsOf OmegaCC , File "res/a.pos", Name "a [Tm]", LastTimeStepOnly onelabInterface ];
                    Print[ mur, OnElementsOf OmegaCC , File "res/mur.pos", Name "mur [-]", LastTimeStepOnly onelabInterface ];
                    Print[ js, OnElementsOf OmegaC_stranded , File "res/js.pos", Name "js [A/m2]", LastTimeStepOnly onelabInterface];
                EndIf
                Print[ mur, OnElementsOf OmegaCC , File "res/mur.pos", Name "mur [-]", LastTimeStepOnly onelabInterface];
                Print[ j, OnElementsOf OmegaC , File "res/j.pos", Name "j [A/m2]", LastTimeStepOnly onelabInterface];
                Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h [A/m]", LastTimeStepOnly onelabInterface];
                Print[ b, OnElementsOf Omega , File "res/b.pos", Name "b [T]", LastTimeStepOnly onelabInterface];
            EndIf
            Print[ torqueMaxwell[Stator_Airgap], OnGlobal, Format TimeTable, File outputMagnetization];
            Print[ m_avg_y_tesla[Magnet1], OnRegion Magnet1, Format TimeTable, File outputMagnetization2];
            Print[ hsVal[Omega], OnRegion Omega, Format TimeTable, File outputAppliedField];
            Print[ j, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                Format TimeTable, File outputCurrent];
            Print[ b, OnPoint {circlePointX_1, circlePointY_1, 0}, Format TimeTable, File outputMagInduction2];
            For k In{2:savedPoints}
                Print[ b, OnPoint {circlePointX~{k}, circlePointY~{k}, 0}, Format TimeTable, File > outputMagInduction2];
            EndFor
            Print[ b, OnLine{{List[controlPoint1]}{List[controlPoint2]}} {savedPoints},
                Format TimeTable, File outputMagInduction1];
        }
    }
}

DefineConstant[
  R_ = {"MagDyn", Name "GetDP/1ResolutionChoices", Visible 0},
  C_ = {"-solve -pos -bin -v 3 -v2", Name "GetDP/9ComputeCommand", Visible 0},
  P_ = { "MagDyn", Name "GetDP/2PostOperationChoices", Visible 0}
];
