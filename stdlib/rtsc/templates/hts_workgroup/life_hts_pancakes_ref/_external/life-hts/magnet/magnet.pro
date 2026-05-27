Include "magnet_data.pro";
Include "H2B_B2H_Vacoflux.pro";
Include "../lib/commonInformation.pro";

Group {
    DefineConstant[onelabInterface = {0, Choices{0,1}, Name "Input/3Problem/2Show solution during simulation?"}]; // Set to 0 for launching in terminal (faster)
    realTimeInfo = 0;
    realTimeSolution = onelabInterface;
    // ------- PROBLEM DEFINITION -------
    // Test name - for output files
    name = "magnet";
    // (directory name for .txt files, not .pos files)
    DefineConstant [testname = "magnet_model_h_alt_test"];
    // ------- WEAK FORMULATION -------
    // Choice of the formulation
    formulation = (preset==1 || preset==5 || preset==7) ? h_formulation : ((preset==2 || preset==6 || preset==8) ? a_formulation : ha_formulation);
    automatic_ha_domains = (preset != 4) ? 1 : 0;
    a_enrichment = (preset == 4) ? 0 : 1; // Enrich a when a in air, and h when h in air.
    alt_formulation = (preset==7 || preset==8);

    // Dimension of the problem
    Dim = 3;
    Flag_hs = (preset == 1 || preset == 5 || preset == 4 || preset == 7) ? 1 : 0; // Source field in stranded region?
    Flag_save_hs = 0; // Save the obtained source field (for verification only, do not put it to 1 otherwise!)
    Nb_source_domain = 1;
    Flag_cohomology = 0; // Do not use it for coupled (not stable when cut touches BndOmega_ha)
    nonlinferro = 1; // 0: just for test (constant permeability)
    nonlinsuper = 1; // 0: just for test too (copper instead)
    Flag_jcb = 1;
    Flag_nb = 1;
    Flag_NormalSign = -1;
    Flag_spurious_conductivity = (preset == 5 || preset == 6); // For comparison (not efficient), use only for h-formulation or a-formulation (not coupled h-a)
    economPos = 0;
    tryrelaxationfactors = 0 * (preset == 1 || preset == 5);
    // ------- Definition of the physical regions -------
    // Filling the regions
    Air = Region[ AIR ];

    If(nonlinsuper == 1)
        Super = Region[ BULK ];
    Else
        Copper = Region[ BULK ];
    EndIf
    BndOmegaC = Region[ BND_BULK_IN ];
    Coil = Region[ COIL ];
    Iron = Region[ IRON ];
    BndIron = Region[ BND_IRON_IN ];
    BndIronSym = Region[ BND_IRON_SYM ];
    ArbitraryPoint = Region[ ARBITRARY_POINT ];

    IsThereSuper = nonlinsuper;
    IsThereFerro = nonlinferro;

    // Fill the regions for formulation
    MagnAnhyDomain = Region[ {Iron} ];
    MagnLinDomain = Region[ {Air, Super, Copper, Coil} ];
    NonLinOmegaC = Region[ {Super} ];
    OmegaC_stranded = Region[ {Coil} ];
    BndOmegaC_stranded = Region[ {BND_COIL_IN} ];
    Omega_noStranded = Region[ {Air, Super, Copper, Iron} ];
    If(Flag_spurious_conductivity == 0)
        LinOmegaC = Region[ {Copper} ];
        OmegaCC = Region[ {Air, Iron, OmegaC_stranded} ];
    Else
        LinOmegaC = Region[ {Air, Coil, Iron, Copper} ];
        BndOmegaC = Region[ {} ];
        OmegaCC = Region[ {} ];
    EndIf
    OmegaC = Region[ {LinOmegaC, NonLinOmegaC} ];
    Omega = Region[ {OmegaC, OmegaCC} ];

    If(Flag_cohomology == 0) // To fix!
        Cuts_stranded = Region[ CUT ];
        BndOmegaC_stranded_side = Region[ ONE_SIDE_OF_CUT ];
    Else
        Cuts_stranded = Region[ (BND_COIL_SYM+1) ]; // BND_COIL_SYM is the ID with largest value
    EndIf
    // Boundaries for BC
    SurfSym = Region[ {SURF_SYM} ];
    SurfOut = Region[ {SURF_OUT} ];
    Gamma_e = Region[{SurfSym, SurfOut}];
    Gamma_h = Region[{}];
    GammaAll = Region[ {Gamma_h, Gamma_e} ];

    If(formulation == coupled_formulation && automatic_ha_domains == 0)
        Omega_h = Region[{MagnLinDomain}];
        Omega_h_AndBnd = Region[{MagnLinDomain, BndIron, BndOmegaC, Gamma_e}];
        Omega_h_OmegaC = Region[{Super, Copper}];
        Omega_h_OmegaC_AndBnd = Region[{Super, Copper, BndOmegaC, Gamma_e}];
        Omega_h_OmegaCC = Region[{Air, Coil}];
        Omega_h_OmegaCC_AndBnd = Region[{Air, Coil, BndOmegaC, BndIron, Gamma_e}];
        Omega_a  = Region[{Iron}];
        Omega_a_AndBnd  = Region[{Iron, BndIron, Gamma_h}];
        Omega_a_OmegaCC = Region[{Iron}];
        BndOmega_ha = Region[{BndIron}];
    EndIf

}


Function{
    // ------- PARAMETERS -------
    // Superconductor parameters
    DefineConstant [jc = pl_Jc0]; // Critical current density [A/m2]
    DefineConstant [n = pl_n]; // Superconductor exponent (n) value [-]
    DefineConstant [n0 = pl_B_n0]; // Superconductor exponent (n) value [-]
    DefineConstant [n1 = pl_B_n1]; // Superconductor exponent (n) value [-]
    DefineConstant [b0 = pl_B_B0]; // Superconductor exponent (n) value [-]
    // Ferromagnetic material parameters
    DefineConstant [mur0 = 1700.0]; // Relative permeability at low fields [-]
    DefineConstant [m0 = 1.04e6]; // Magnetic field at saturation [A/m]

    // Excitation - Source field or imposed current intensty
    // 0: sine, then decaying exp
    // 1: sine
    DefineConstant [Flag_Source = 0];
    DefineConstant [timeStart = 0]; // Initial time [s]
    DefineConstant [timeFinalSimu = 10*T_peak]; // Final time of simulation [s]

    // Numerical parameters
    DefineConstant [dt = T_peak/80]; // Time step (initial if adaptive)[s]
    DefineConstant [writeInterval = dt]; // Time interval between two successive output file saves [s]
    Flag_variable_dt_max = 1; // Variable maximum time step -> see in Function{ ... }
    DefineConstant [tol_energy = (preset==1 || preset==2 || preset==5 || preset==6) ? 1e-5 : 1e-6]; // Relative tolerance on the energy estimates (1e-10 for j distr. as in the article)
    DefineConstant [iter_max = (preset==1 || preset==2 || preset==5 || preset==6) ? 400 : 50]; // Maximum number of nonlinear iterations
    DefineConstant [extrapolationOrder = (formulation==a_formulation) ? 2 : 1]; // Extrapolation order
    // Control points
    controlPoint1 = {0, 0, -3*bulk_h}; // CP1
    controlPoint2 = {Sqrt[0.5]*air_r/2,Sqrt[0.5]*air_r/2, -3*bulk_h}; // CP2
    controlPoint3 = {0, 0, 3*bulk_h}; // CP3
    //controlPoint1 = {bulk_r + air_space/2,bulk_r + air_space/2, -1.5*bulk_h}; // CP1
    //controlPoint2 = {bulk_r + air_space/2 + 1.5*Sqrt[0.5]*bulk_r,bulk_r + air_space/2 + 1.5*Sqrt[0.5]*bulk_r, -1.5*bulk_h}; // CP2
    //controlPoint3 = {bulk_r + air_space/2,bulk_r + air_space/2, bulk_h/2}; // CP3
    controlPoint4 = {0, 0, -bulk_h/2-bulk_h/2-space_i}; // CP4
    controlPoint5 = {2*bulk_r + air_space, 0, -bulk_h/2-bulk_h/2-space_i}; // CP5
    controlPoint6 = {bulk_r + air_space/2 - Sqrt[0.5]*bulk_r, bulk_r + air_space/2 - Sqrt[0.5]*bulk_r, bulk_h/2+2e-3}; // CP6
    controlPoint7 = {Sqrt[0.5]*air_r/2, Sqrt[0.5]*air_r/2, bulk_h/2+2e-3}; // CP7
    controlPoint8 = {bulk_r + air_space/2,bulk_r + air_space/2, 0}; // CP1
    controlPoint9 = {bulk_r + air_space/2 + Sqrt[0.5]*bulk_r,bulk_r + air_space/2 + Sqrt[0.5]*bulk_r, 0};
    savedPoints = 200; // Resolution of the line saving postprocessing
}

Include "../lib/lawsAndFunctions.pro";

Function{
    If(Flag_Source == 0)
        controlTimeInstants = {timeFinalSimu, 2*timeFinalSimu};
        I_tot[] = coil_N * Imax * (($Time < T_peak) ? Sin[Pi/2 * $Time/T_peak] :
            Exp[-100*($Time-T_peak)]); // Current intensity applied in the inductor
        dt_max_var[] = ($Time < T_peak) ? dt : (($Time < 2*T_peak) ? 5*dt : (($Time < 4*T_peak) ? 10*dt : (($Time < 5*T_peak) ? 20*dt : (($Time < 10*T_peak) ? 40*dt : 80*dt))));
    ElseIf(Flag_Source == 1)
        controlTimeInstants = {timeFinalSimu, 2*timeFinalSimu};
        I_tot[] = coil_N * Imax * Sin[Pi/2 * $Time/T_peak] ;
        dt_max_var[] = dt;
    ElseIf(Flag_Source == 4)
        // TBC...
    EndIf

    theta[] = Atan2[Y[] - (bulk_r + air_space/2), X[] - (bulk_r + air_space/2)];
    js0[Coil] = 1/coil_cross * ((Y[] <= bulk_r + air_space/2) ? Vector[0,1,0] :
                    Vector[-Sin[theta[]], Cos[theta[]], 0]); // For a total current of 1 A in the cross-section
    js[Coil] = I_tot[]*js0[];
    // Permeability
    // Automatic in Super and Air regions
    // Coil
    mu[Coil] = mu0;
    nu[Coil] = nu0;
    // Iron (nonlinear, from a list)
    epsMu_Vacoflux = 1e-15;
    hMin_Vacoflux = 16;
    h2b[] = InterpolationLinear[$1]{List[h2b_Vacoflux]};
    mu_Vacoflux[] = ($1 < hMin_Vacoflux ) ? mur0_Vacoflux*mu0 : h2b[$1] / ($1 + epsMu_Vacoflux);
    dh = 1;
    dmudh_Vacoflux[] = (mu_Vacoflux[$1+dh] - mu_Vacoflux[$1])/dh;
    epsNu_Vacoflux = 1e-10;
    bMin_Vacoflux = 0.239673;
    b2h[] = InterpolationLinear[$1]{List[b2h_Vacoflux]};
    nu_Vacoflux[] = ($1 < bMin_Vacoflux ) ? nu0/mur0_Vacoflux : b2h[$1] / ($1 + epsNu_Vacoflux);
    db = dh*2000*mu0;
    dnudb_Vacoflux[] = (nu_Vacoflux[$1+db] - nu_Vacoflux[$1])/db;
    If(nonlinferro == 1)
        mu[Iron] = mu_Vacoflux[Norm[$1]];
        dbdh[Iron] = TensorDiag[1,1,1]*mu_Vacoflux[Norm[$1]#1] + dmudh_Vacoflux[#1]/(#1+epsMu_Vacoflux) * SquDyadicProduct[$1] ;
        nu[Iron] = nu_Vacoflux[Norm[$1]];
        dhdb[Iron] = TensorDiag[1,1,1]*nu_Vacoflux[Norm[$1]#1] + dnudb_Vacoflux[#1]/(#1+epsNu_Vacoflux) * SquDyadicProduct[$1] ;
    Else // For test
        murlin = 2000;
        mu[Iron] = murlin*mu0;
        dbdh[Iron] = murlin*mu0;
        nu[Iron] = nu0/murlin;
        dhdb[Iron] = nu0/murlin;
    EndIf

    If(Flag_spurious_conductivity == 1)
        spuriousResistivity = 1e-3;
        rho[Air] = spuriousResistivity;
        rho[Iron] = spuriousResistivity;
        rho[Coil] = spuriousResistivity;
        spuriousConductivity = 1;
        sigma[Air] = spuriousConductivity;
        sigma[Iron] = spuriousConductivity;
        sigma[Coil] = spuriousConductivity;
    EndIf

}


Constraint {
    { Name a ;
        Case {
            //{ Region Gamma_e; Value 0.0; }
        }
    }
    { Name a2 ;
        Case {
        }
    }
    { Name j ;
        Case {
            { Region Gamma_e; Value 0.0; }
        }
    }
    { Name phi ;
        Case {
            { Region ArbitraryPoint; Value 0.0; }
            // {Region SurfOut ; Value XYZ[]*Vector[0,0,1] ; TimeFunction Sin[$Time] ;}
        }
    }
    { Name h ;
        Case {

        }
    }
    { Name b ;
        Case {
            { Region Gamma_e; Value 0.0; }
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
    { Name Current_s ;
        Case {
            { Region Coil; Value 1.0; TimeFunction I_tot[]; }
        }
    }
    { Name Voltage_s ;
    }
}


Include "../lib/jac_int.pro";
Include "../lib/hs_sourceField.pro";
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
                    If(alt_formulation)
                        Print[ b_alt, OnElementsOf Iron , File "res/b_alt.pos", Name "b_alt [T]" ];
                    EndIf
                ElseIf(formulation == a_formulation)
                    Print[ a, OnElementsOf Omega , File "res/a.pos", Name "a [Tm]" ];
                    Print[ ur, OnElementsOf OmegaC , File "res/ur.pos", Name "ur [V/m]" ];
                    If(alt_formulation)
                        Print[ j_alt, OnElementsOf OmegaC , File "res/j_alt.pos", Name "j_alt [A/m2]" ];
                    EndIf
                ElseIf(formulation == coupled_formulation)
                    Print[ a, OnElementsOf Omega_a , File "res/a.pos", Name "a [Tm]" ];
                EndIf
                Print[ j, OnElementsOf OmegaC , File "res/j.pos", Name "j [A/m2]" ];
                Print[ js, OnElementsOf OmegaC_stranded , File "res/js.pos", Name "js [A/m2]" ];
                Print[ mur, OnElementsOf Iron , File "res/mur.pos", Name "mur [-]" ];
                Print[ e, OnElementsOf OmegaC , File "res/e.pos", Name "e [V/m]" ];
                Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h [A/m]" ];
                Print[ b, OnElementsOf Omega , File "res/b.pos", Name "b [T]" ];
                //Print[ normal, OnElementsOf Cuts_stranded , File "res/normal.pos", Name "n [-]" ];
            EndIf
            // Print[ normal_j, OnElementsOf OmegaC , File "res/j_normal.pos", Name "j [A/m2]" ];
            Print[ hsVal[Omega], OnRegion Omega, Format TimeTable, File outputAppliedField];
            Print[ j, OnLine{{List[controlPoint8]}{List[controlPoint9]}} {savedPoints},
                Format TimeTable, File outputCurrent];
            Print[ b, OnLine{{List[controlPoint4]}{List[controlPoint5]}} {savedPoints},
                Format TimeTable, File outputMagInduction1];
            Print[ b, OnLine{{List[controlPoint6]}{List[controlPoint7]}} {savedPoints},
                Format TimeTable, File outputMagInduction2];
            Print[ h, OnLine{{List[controlPoint4]}{List[controlPoint5]}} {savedPoints},
                Format TimeTable, File outputMagField1];
            //Print[ b, OnPlane{{List[controlPoint1]}{List[controlPoint2]}{List[controlPoint3]}} {70,70},
            //    File "res/b_onPlane.pos"];
            Print[ m_avg[OmegaC], OnRegion OmegaC, Format TimeTable, File outputMagnetization];
        }
    }
    { Name js_to_hs~{Nb_source_domain};
        NameOfPostProcessing js_to_hs~{Nb_source_domain};
        Operation{
            Print[ hs, OnElementsOf Omega , File "res/hs.pos", Name "hs [A/m]" ];
            Print[ js, OnElementsOf OmegaC_stranded , File "res/js.pos", Name "js [A/m2]" ];
            Print[ js0, OnElementsOf OmegaC_stranded , File "res/js0.pos", Name "js0 [A/m2]" ];
        }
    }
}


DefineConstant[
  R_ = {"MagDyn", Name "GetDP/1ResolutionChoices", Visible 0},
  C_ = {"-solve -pos -bin -v 3 -v2", Name "GetDP/9ComputeCommand", Visible 0},
  P_ = { "MagDyn", Name "GetDP/2PostOperationChoices", Visible 0}
];
