Include "../common/pancakes_data.pro";
Include "../lib/commonInformation.pro";

// simultaneous multi-scale h-phi thin-shell formulation for stacked pancakes
// see E. Berrospe et al., SUST, 2021 for simultaneous multi-scale method
// see B. de Sousa Alves et al., SUST, 2021 for h-phi thin-shell formulation.
// see L. Denis et al., in press, 2025 for combination of both.


Group {
    // ------- PROBLEM DEFINITION -------
    name = "pancakes_smsts/";

    N_ele = N_ele_bis;
    Delta = H_tape/(N_ele); // Virtual elements size thin-shell
    DefineConstant [testname = StrCat["smsts_", Sprintf["%g", num_pancakes], "_pancakes_", Sprintf["%g", num_analyzed_tapes], "_tapes_out_of_", Sprintf["%g", num_tapes]]]; // Test name - for output files

    nbConductors = num_analyzed_tapes * num_pancakes;
    nb_source_domains = (num_analyzed_tapes - 1) * num_pancakes;
    
    nbConductors_per_pancake = num_analyzed_tapes;
    nb_source_domains_per_pancake = num_analyzed_tapes - 1;

    nb_eff_source_domains = 0;
    For i In {1:nb_source_domains_per_pancake}
        If(analyzed_tapeID~{i+1} - analyzed_tapeID~{i} > 1)
            nb_eff_source_domains += num_pancakes;
            For j In {1:num_pancakes}
                is_eff_source_dom~{i+nb_source_domains_per_pancake*(j-1)} = 1;
            EndFor
        Else
            For j In {1:num_pancakes}
                is_eff_source_dom~{i+nb_source_domains_per_pancake*(j-1)} = 0;
            EndFor
        EndIf
    EndFor

    If(num_analyzed_tapes < num_tapes) // default
        THICK_CUT = SURF_OUT+4*(nb_eff_source_domains/num_pancakes)*num_pancakes+2*num_analyzed_tapes*num_pancakes+1; // It will be different depending on the other physical IDs
    Else // reference thin-shell only model: no cuts related to source domains
        THICK_CUT = SURF_OUT+2*num_analyzed_tapes*num_pancakes+1;
    EndIf
    THICK_CUT = THICK_CUT+num_analyzed_tapes*num_pancakes;
    CUT_SOURCE = SURF_OUT+3*(nb_eff_source_domains/num_pancakes)*num_pancakes+1;

    Air = Region[ AIR ];
    For i In {1:num_pancakes}
        Air~{i} = Region[ (AIR + num_pancakes + i) ]; // outer air only, still the air between tapes to be added
    EndFor

    // Filling the regions related to the thin shells
    // Positive and negative sides (UP and DOWN - 1 and 0) of the shell representing the tape in the h_phi_ts_formulation
    GammaTS_1 = Region[ {} ]; // top parts
    GammaTS_0 = Region[ {} ]; // bottom parts

    TS_EdgeLeft = Region[{}];
    TS_EdgeRight = Region[{}];

    BndOmegaC = Region[{}];
    For i In {1:nbConductors}
        BndOmegaC += Region[ (TS_FULL + TS_OFFSET*(i-1)) ];
        Cut~{i} = Region[ (THICK_CUT + (i-1)) ]; // for imposing the net current

        GammaTS_1 += Region[ (TS_UP + TS_OFFSET*(i-1)) ];
        GammaTS_0 += Region[ (TS_DOWN + TS_OFFSET*(i-1)) ];

        GammaTS_0~{i} = Region[ (TS_DOWN + TS_OFFSET*(i-1)) ]; // useful for computing the ac losses in each conductor separately

        TS_EdgeLeft += Region[ (TS_EDGE_LEFT + TS_OFFSET*(i-1)) ];
        TS_EdgeRight += Region[ (TS_EDGE_RIGHT + TS_OFFSET*(i-1)) ];
    EndFor
    GammaTS = Region[{GammaTS_0, GammaTS_1}];
    TS_LateralEdges = Region[ {TS_EdgeLeft, TS_EdgeRight} ];

    OmegaS = Region[ {} ]; // contains all source domains
    BndOmegaS = Region[ {} ]; // contains all boundaries of source domains
    eff_source_dom_ID = 0; // will be incremented in next loop (counting number of effective source domains we've gone through)
    For i In {1:num_pancakes}
        For j In {1:nb_source_domains_per_pancake}
            AirAux~{nb_source_domains_per_pancake*(i-1)+j} = Region[ (BULK+BULK_OFFSET*(num_analyzed_tapes-1)*(i-1) + BULK_OFFSET * (j-1) - 1) ]; // air between tapes
            Air~{i} += Region[ {AirAux~{nb_source_domains_per_pancake*(i-1)+j}} ]; // filling air domain
            // check if we are in an effective source domain.
            If(eff_source_dom_ID < nb_eff_source_domains && is_eff_source_dom~{nb_source_domains_per_pancake*(i-1)+j} == 1)
                eff_source_dom_ID += 1;

                OmegaS~{eff_source_dom_ID} = Region[ (BULK+BULK_OFFSET*nb_source_domains_per_pancake*(i-1) + BULK_OFFSET*(j-1)) ]; // one per source domain.
                OmegaS += Region[ {OmegaS~{eff_source_dom_ID}} ];
                // ! for BndOmegaS~{i} we must manually add the correct boundaries, knowing that the mesh entity of each bulk domain contains only the lower parts of the cracks (the bottom lower part must be replaced by the corresponding upper part)
                BndOmegaS~{eff_source_dom_ID} = Region[ (BND_BULK+BULK_OFFSET*nb_source_domains_per_pancake*(i-1) + BULK_OFFSET*(j-1)) ];
                TS_up_aux~{eff_source_dom_ID} = Region[ (TS_UP+TS_OFFSET*nbConductors_per_pancake*(i-1) + TS_OFFSET*(j-1)) ];
                TS_down_aux~{eff_source_dom_ID} = Region[ (TS_DOWN+TS_OFFSET*nbConductors_per_pancake*(i-1) + TS_OFFSET*(j-1)) ];

                BndOmegaS += Region[ {BndOmegaS~{eff_source_dom_ID}} ];

                TS_down_aux_next~{eff_source_dom_ID} = Region[ (TS_DOWN+TS_OFFSET*nbConductors_per_pancake*(i-1) + TS_OFFSET*(j)) ];

                Cut_source~{eff_source_dom_ID} = Region[ (CUT_SOURCE+nb_eff_source_domains/num_pancakes*(i-1) + j - 1) ];

                AirAroundSource~{eff_source_dom_ID} = Region[ {AirAux~{nb_source_domains_per_pancake*(i-1)+j}} ]; // useful for definition of js fields
            EndIf
        EndFor
    EndFor

    For i In {1:num_pancakes}
        Air += Region[ {Air~{i}} ]; // filling air domain
    EndFor

    // Fill the regions for formulation
    MagnLinDomain = Region[ {Air} ];
    NonLinOmegaC = Region[ {GammaTS} ];

    LinOmegaC = Region[ {} ];
    OmegaC = Region[ {LinOmegaC, NonLinOmegaC} ];
    OmegaCC = Region[ {Air, OmegaS} ];
    Omega = Region[ {OmegaC, OmegaCC} ];
    ArbitraryPoint = Region[ ARBITRARY_POINT ]; // To fix the potential

    // Boundaries for BC
    SurfOut = Region[ SURF_OUT ];
    SurfSym = Region[{SURF_SYM_BOT, SURF_SYM_LEFT} ];
    Gamma_h = Region[{SurfOut}];
    Gamma_e = Region[{SurfSym}];
    GammaAll = Region[ {Gamma_h, Gamma_e} ];
}


Function{
    formulation = 3; // SMSTS: formulation = 3
    fill_factor = 1.0;

    DefineConstant [try_ASM_before_MUMPS = 0]; // Try ASM before MUMPS (for debugging purposes)
    Flag_try_ASM_before_MUMPS = try_ASM_before_MUMPS;

    PythonTapeIDs = Sprintf["%g %g %g", num_pancakes, num_tapes, num_analyzed_tapes];
    For i In {1:num_analyzed_tapes}
        PythonTapeIDs = StrCat[PythonTapeIDs, Sprintf[" %g", analyzed_tapeID~{i}]];
    EndFor

    tol_rel = 1e-6; // Relative tolerance on nonlinear residual
    tol_abs = 4e-7; // Absolute tolerance on nonlinear residual
    If(num_analyzed_tapes == num_tapes)
        tol_abs = 1e-8; // classical thin shell
    EndIf
}

Include "../common/pancakes_functions.pro";

Function {
    Is_modulation[] = Sin[2.0 * Pi * f * $Time];
    mu[OmegaS] = mu0;
    mu[GammaTS] = mu0;

    eff_source_dom_ID = 0;
    For i In {1:num_pancakes}
        For j In {1:nb_source_domains_per_pancake}
            // check if we are in an effective source domain.
            // If it's the case, compute the number of tapes inside the source domain.
            If(eff_source_dom_ID < nb_eff_source_domains && is_eff_source_dom~{nb_source_domains_per_pancake*(i-1)+j} == 1)
                eff_source_dom_ID += 1;
                num_tapes_in_source_dom~{eff_source_dom_ID} = analyzed_tapeID~{j+1} - analyzed_tapeID~{j} - 1;
                Is_max~{eff_source_dom_ID} = num_tapes_in_source_dom~{eff_source_dom_ID} * Imax; // [A]
                my_fill_factor[Region[{OmegaS~{eff_source_dom_ID}, TS_down_aux_next~{eff_source_dom_ID}, TS_up_aux~{eff_source_dom_ID}}]] = H_tape / d_btw_tapes;

                // for extrusion constraint
                Y_bottom~{eff_source_dom_ID} = H_turn/2 + d_btw_tapes * (analyzed_tapeID~{j} - 1);
                Y_top~{eff_source_dom_ID} = H_turn/2 + d_btw_tapes * (analyzed_tapeID~{j+1} - 1);

                // first order global basis functions
                theta_bottom[OmegaS~{eff_source_dom_ID}] = 1 - ((Y[] - Y_bottom~{eff_source_dom_ID})/(Y_top~{eff_source_dom_ID} - Y_bottom~{eff_source_dom_ID}));
                theta_top[OmegaS~{eff_source_dom_ID}] = (Y[] - Y_bottom~{eff_source_dom_ID})/(Y_top~{eff_source_dom_ID} - Y_bottom~{eff_source_dom_ID});
            EndIf
        EndFor
    EndFor

    // used for computing ac loss density in source domains, directly in GetDP code. Not used currently.
    If(nb_eff_source_domains > 0)
        eff_fill_factor = H_tape / d_btw_tapes;
        rho_hom_power[OmegaS] = ec / (eff_fill_factor * jcb[$2])#8 * (Min[1e99, Norm[$1]]/#8)^(n - 1); // $1 is js in vector, $2 is b vector
    EndIf
}


Constraint {
    { Name hr ;
    }
    { Name phi ;
        Case {
            {Region ArbitraryPoint ; Value 0.0;}
            {Region SurfSym; Value 0.0;}
        }
    }
    For i In {1:num_pancakes} 
        For j In {1:nbConductors_per_pancake}
            { Name Current~{nbConductors_per_pancake*(i-1)+j} ; Type Assign;
                Case {
                    // merging all cuts btw successive conductors into single phi discontinuities, makes the cuts more localized
                    // localized cuts: each cut carries the current of all tapes below it
                    { Region Cut~{nbConductors_per_pancake*(i-1)+j}; Value j*1.0; TimeFunction I[]; }
                }
            }
            { Name Voltage~{nbConductors_per_pancake*(i-1)+j} ; Case { } } // for h-phi-form
        EndFor
    EndFor

    { Name Connect; // required link Dofs in the h-phi_ts_formulation
		Case {
            { Region GammaTS_1; Type Link ; RegionRef GammaTS_0;
                Coefficient 1; Function Vector[$X,$Y,$Z] ;
            }
        }
	}

    For i In {1:nb_eff_source_domains}
        { Name Bottom_extrusion~{i};
            Case {
                { Region OmegaS~{i}; Type Link ; RegionRef TS_up_aux~{i};
                    Coefficient 1; Function Vector[$X,Y_bottom~{i},$Z];
                }
                { Region TS_down_aux~{i}; Type Link ; RegionRef TS_up_aux~{i};
                    Coefficient 1; Function Vector[$X,$Y,$Z] ;
                } // continuity of j_ext_bot across the crack
            }
        }
        { Name Top_extrusion~{i};
            Case {
                { Region OmegaS~{i}; Type Link ; RegionRef TS_down_aux_next~{i};
                    Coefficient 1; Function Vector[$X,Y_top~{i},$Z];
                }
            }
        }
    EndFor

    { Name GaugeCondition_hs_tot ; Type Assign ;
        Case {
            { Region OmegaS ; SubRegion BndOmegaS ; Value 0. ; }
        }
    }
    For i In {1:nb_eff_source_domains}
        { Name Current_s_tot~{i} ; Type Assign ;
            Case {
                { Region Cut_source~{i}; Value Is_max~{i}; TimeFunction Is_modulation[]; }
            }
        }
    EndFor

}

Include "../lib/jac_int.pro";

FunctionSpace {
    // single hs field, for all source domains
    { Name hs_space_tot; Type Form1;
        BasisFunction {
            { Name psie; NameOfCoef he; Function BF_Edge;
                Support Region[{OmegaS}]; Entity EdgesOf[OmegaS, Not BndOmegaS]; }
            For i In {1:nb_eff_source_domains}
                { Name sc; NameOfCoef Isi~{i}; Function BF_GroupOfEdges;
                    Support Omega_h_AndBnd; Entity GroupsOfEdgesOf[Cut_source~{i}]; }
            EndFor
        }
        Constraint {
            { NameOfCoef he; EntityType EdgesOfTreeIn; EntitySubType StartingOn;
                NameOfConstraint GaugeCondition_hs_tot; }
            For i In {1:nb_eff_source_domains}
                { NameOfCoef Isi~{i}; EntityType GroupsOfEdgesOf ; NameOfConstraint Current_s_tot~{i}; }
            EndFor
        }
    }
    // Function spaces for thin-shell model (Bruno de Sousa Alves)
    { Name HPhiTSSpace; Type Form1;
        BasisFunction {
            { Name sn; NameOfCoef phin; Function BF_GradNode;
                Support Region[{OmegaCC,GammaTS}]; Entity NodesOf[OmegaCC, Not {GammaTS}]; }

            { Name sn_u; NameOfCoef phin_u; Function BF_GradNode;
                    Support Region[{OmegaCC,GammaTS}]; Entity NodesOf[GammaTS_1, Not TS_LateralEdges]; } // Defined over \Gamma_s^+ only
    
            { Name sn_d; NameOfCoef phin_d; Function BF_GradNode;
                    Support Region[{OmegaCC,GammaTS}]; Entity NodesOf[GammaTS_0, Not TS_LateralEdges]; } // Defined over \Gamma_s^- only.
    

            { Name sn_p; NameOfCoef phin_p; Function BF_GradNode; // Defined over the extreme points (lateral edges) of the \Gamma_s, i.e. \partial\Gamma_s
                Support Region[{OmegaCC,GammaTS}]; Entity NodesOf[TS_LateralEdges]; }
            For i In {1:nbConductors}
                { Name sc; NameOfCoef I~{i}; Function BF_GroupOfEdges;
                    Support Omega_h_AndBnd; Entity GroupsOfEdgesOf[Cut~{i}]; }
            EndFor
        }
        GlobalQuantity {
            For i In {1:nbConductors}
                { Name Current~{i} ; Type AliasOf        ; NameOfCoef I~{i} ; }
                { Name Voltage~{i} ; Type AssociatedWith ; NameOfCoef I~{i} ; }
            EndFor
        }
        SubSpace {
            If(nbConductors > 0)
                { Name GammaTS_up; NameOfBasisFunction {sn_u,sc,sn_p}; } // includes grad(phi) in \Gamma_s^+ and in its edges, and the thick cut (if it is thouching \Gamma_s^+)
                { Name GammaTS_down; NameOfBasisFunction {sn_d,sc,sn_p}; } // includes grad(phi) in \Gamma_s^- and in its edges, and the thick cut (if it is thouching \Gamma_s^-)
            Else
                { Name GammaTS_up; NameOfBasisFunction {sn_u,sn_p}; }
                { Name GammaTS_down;   NameOfBasisFunction {sn_d,sn_p}; }
            EndIf
        }
        Constraint {
            { NameOfCoef phin; EntityType NodesOf; NameOfConstraint phi; }
            For i In {1:nbConductors}
                { NameOfCoef Current~{i} ;
                    EntityType GroupsOfEdgesOf ; NameOfConstraint Current~{i} ; }
                { NameOfCoef Voltage~{i}  ;
                    EntityType GroupsOfEdgesOf ; NameOfConstraint Voltage~{i} ; }
            EndFor
        }

    }
    // Inside the thin shell
    For i In {1:N_ele}
        { Name HPhiTSSpace~{i} ; Type Form1 ;
            BasisFunction {
            { Name se ; NameOfCoef he~{i} ; Function BF_Edge ;
                Support Region[{GammaTS_0}] ; Entity EdgesOf[ GammaTS_0 ] ; } // Defined on \Gamma_s^- only
            }
            Constraint {
            }
        }
    EndFor

    // Inside the thin shell
    { Name HPhiTSSpace~{N_ele+1} ; Type Form1 ;
        BasisFunction {
            { Name se ; NameOfCoef he~{N_ele+1} ; Function BF_Edge ;
            Support Region[{GammaTS}] ; Entity EdgesOf[ GammaTS ] ; } // Defined on \Gamma_s=\Gamma_s^+ \cup \Gamma_s^-
        }
        Constraint {
            { NameOfCoef he~{N_ele+1} ;
            EntityType EdgesOf ; NameOfConstraint Connect ; } // Link constraint with coefficient 1
        }
    }

    { Name bn_perp_TS_space ; Type Form2; // For normal component of magnetic flux induction in thin shells
        BasisFunction {
            { Name psif_tot; NameOfCoef bn_perp_f; Function BF_PerpendicularFacet;
                Support Region[{OmegaCC,GammaTS}]; Entity EdgesOf[GammaTS]; } // defined over both top and bottom surfaces
        }
        Constraint {
            { NameOfCoef bn_perp_f;
            EntityType EdgesOf; NameOfConstraint Connect; }
        }
    }

    For i In {1:nb_eff_source_domains}
        { Name j_extruded_bottom_space~{i}; Type Form0 ;
            BasisFunction {
                { Name psi_j_ext_bot_n~{i} ; NameOfCoef j_ext_bot_n~{i} ; Function BF_Node ;
                Support Region[{OmegaS~{i},AirAroundSource~{i},TS_down_aux~{i},TS_up_aux~{i}}] ; Entity NodesOf[{OmegaS~{i}, AirAroundSource~{i}, TS_down_aux~{i}}] ; }
            }
            Constraint {
                { NameOfCoef j_ext_bot_n~{i};
                EntityType NodesOf; NameOfConstraint Bottom_extrusion~{i}; } // also includes link constraint for continuity of the dof values across the bottom thin shell
            }
        }
        { Name j_extruded_top_space~{i}; Type Form0 ;
            BasisFunction {
                { Name psi_j_ext_top_n~{i} ; NameOfCoef j_ext_top_n~{i} ; Function BF_Node ;
                Support Region[{OmegaS~{i},AirAroundSource~{i},TS_down_aux_next~{i}}] ; Entity NodesOf[{OmegaS~{i}, AirAroundSource~{i}}] ; }
            }
            Constraint {
                { NameOfCoef j_ext_top_n~{i};
                EntityType NodesOf; NameOfConstraint Top_extrusion~{i}; }
            }
        }
    EndFor
}

Formulation {
    { Name MagDyn_hphits_monolithic; Type FemEquation;
        Quantity {
            { Name hr; Type Local; NameOfSpace HPhiTSSpace; }
            { Name hs; Type Local; NameOfSpace hs_space_tot; }
            For i In {1:nb_eff_source_domains}
                { Name j_ext_bot~{i}; Type Local; NameOfSpace j_extruded_bottom_space~{i}; }
                { Name j_ext_top~{i}; Type Local; NameOfSpace j_extruded_top_space~{i}; }
            EndFor
            For i In {1:nbConductors}
                { Name I~{i}; Type Global; NameOfSpace HPhiTSSpace[Current~{i}]; }
                { Name V~{i}; Type Global; NameOfSpace HPhiTSSpace[Voltage~{i}]; }
            EndFor

            { Name hi~{0}; Type Local; NameOfSpace HPhiTSSpace[GammaTS_down]; }
            If(nbConductors > 0)
                For i In {1:N_ele+1}
                    { Name hi~{i}  ; Type Local ; NameOfSpace HPhiTSSpace~{i} ; }
                EndFor
            EndIf
            { Name hi~{N_ele+2}; Type Local; NameOfSpace HPhiTSSpace[GammaTS_up]; }
            If(Flag_jcb)
                { Name bn_perp; Type Local; NameOfSpace bn_perp_TS_space; }
            EndIf

        }
        Equation {
            // PART 1: HS FORMULATION
            For i In {1:nb_eff_source_domains}
                Galerkin { [  Dof{d hs}, {d hs} ] ;
                In OmegaS~{i} ; Jacobian Vol ; Integration Int ; }
                Galerkin { [ - Vector[0.,0.,1.] * my_fill_factor[] * theta_bottom[] * Dof{j_ext_bot~{i}}, {d hs} ] ; 
                In OmegaS~{i} ; Jacobian Vol ; Integration Int ; }
                Galerkin { [ - Vector[0.,0.,1.] * my_fill_factor[] * theta_top[] * Dof{j_ext_top~{i}}, {d hs} ] ; 
                In OmegaS~{i} ; Jacobian Vol ; Integration Int ; }
            EndFor

            // PART 2: HFULL (TS) FORMULATION
            Galerkin { DtDof[ mu[] * Dof{hr} , {hr} ];
            In OmegaCC; Integration Int; Jacobian Vol;}

            // NEW (incredibly important) TERM HERE FOR considering hs
            Galerkin { DtDof[ mu[] * Dof{hs}, {hr} ];
            In OmegaCC; Integration Int; Jacobian Vol; }

            If(Flag_compute_voltage)
                For i In {1:nbConductors}
                    GlobalTerm { [ Dof{V~{i}} , {I~{i}} ] ; In Cut~{i} ; }
                EndFor
            EndIf

            // TS model
            If(nbConductors > 0)
                For i In {0:N_ele+1}
                    If (i==0 || i== N_ele+1) //explicitly connect h=-\grad(\phi)
                        Galerkin {  [ Dof{hi~{i}} , {hi~{i}} ];
                        In GammaTS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ - Dof{hi~{i}} , {hi~{i+1}} ];
                        In GammaTS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ - Dof{hi~{i+1}} , {hi~{i}} ];
                        In GammaTS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ Dof{hi~{i+1}} , {hi~{i+1}} ];
                        In GammaTS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}
                    Else
                        Galerkin {  DtDof[ 2 * mu0 * Delta/6 * Dof{hi~{i}}, {hi~{i}} ];
                        In GammaTS_0; Integration Int; Jacobian Sur;}

                        Galerkin {  DtDof[ mu0 * Delta/6 * Dof{hi~{i}}, {hi~{i+1}} ];
                        In GammaTS_0; Integration Int; Jacobian Sur;}

                        Galerkin {  DtDof[ mu0 * Delta/6 * Dof{hi~{i+1}}, {hi~{i}} ];
                        In GammaTS_0; Integration Int; Jacobian Sur;}

                        Galerkin {  DtDof[ 2 * mu0 * Delta/6 * Dof{hi~{i+1}}, {hi~{i+1}} ];
                        In GammaTS_0; Integration Int; Jacobian Sur;}

                        If(Flag_jcb == 1) // rho_power_TS_built_in and drhodj_timesj_power_TS_built_in takes bn_perp as a vector as a third input
                            Galerkin {  [ 1/Delta * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * Dof{hi~{i}} , {hi~{i}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin {  [ - 1/Delta * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * Dof{hi~{i}} , {hi~{i+1}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin {  [ - 1/Delta * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * Dof{hi~{i+1}} , {hi~{i}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin {  [ 1/Delta * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * Dof{hi~{i+1}} , {hi~{i+1}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            // update part of NR: linear part in the unknown DOF
                            Galerkin {  JacNL[ 1/Delta * drhodj_timesj_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * Dof{hi~{i}} , {hi~{i}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin {  JacNL[ - 1/Delta * drhodj_timesj_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * Dof{hi~{i}} , {hi~{i+1}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin {  JacNL[ - 1/Delta * drhodj_timesj_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * Dof{hi~{i+1}} , {hi~{i}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin {  JacNL[ 1/Delta * drhodj_timesj_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * Dof{hi~{i+1}} , {hi~{i+1}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}
                        Else
                            Galerkin {  [ 1/Delta * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i}} , {hi~{i}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin {  [ - 1/Delta * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i}} , {hi~{i+1}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin {  [ - 1/Delta * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i+1}} , {hi~{i}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin {  [ 1/Delta * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i+1}} , {hi~{i+1}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            // update part of NR: linear part in the unknown DOF
                            Galerkin { JacNL[ 1/Delta * drhodj_timesj_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i}} , {hi~{i}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin { JacNL[ - 1/Delta * drhodj_timesj_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i}} , {hi~{i+1}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin { JacNL[ - 1/Delta * drhodj_timesj_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i+1}} , {hi~{i}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}

                            Galerkin { JacNL[ 1/Delta * drhodj_timesj_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i+1}} , {hi~{i+1}} ];
                            In GammaTS_0; Integration Int; Jacobian Sur;}
                        EndIf
                    EndIf
                EndFor
            EndIf

            If(Flag_jcb) 
                Galerkin {  [ Dof{bn_perp}, {bn_perp} ];
                    In GammaTS_1; Integration Int; Jacobian Sur;} 
                Galerkin { [ - mu[] * SquDyadicProduct[normal_vector[]] * Trace[ Dof{hr} , ElementsOf[OmegaCC, ConnectedTo GammaTS_1] ] , {bn_perp} ] ;
                    In GammaTS_1; Integration Int; Jacobian Sur;}
                Galerkin { [ - mu[] * SquDyadicProduct[normal_vector[]] * Trace[ Dof{hs} , ElementsOf[OmegaCC, ConnectedTo GammaTS_1] ] , {bn_perp} ] ;
                    In GammaTS_1; Integration Int; Jacobian Sur;}
                Galerkin {  [ Dof{bn_perp}, {bn_perp} ];
                    In GammaTS_0; Integration Int; Jacobian Sur;} 
                Galerkin { [ - mu[] * SquDyadicProduct[normal_vector[]] * Trace[ Dof{hr} , ElementsOf[OmegaCC, ConnectedTo GammaTS_0] ] , {bn_perp} ] ;
                    In GammaTS_0; Integration Int; Jacobian Sur;}
                Galerkin { [ - mu[] * SquDyadicProduct[normal_vector[]] * Trace[ Dof{hs} , ElementsOf[OmegaCC, ConnectedTo GammaTS_0] ] , {bn_perp} ] ;
                    In GammaTS_0; Integration Int; Jacobian Sur;}
            EndIf

            // PART 3: JSZ FORMULATION (linear interpolation)
            For i In {1:nb_eff_source_domains}
                Integral { [ Dof{j_ext_top~{i}} , {j_ext_top~{i}} ] ;
                    In Region[{TS_down_aux_next~{i}}]; Integration Int ; Jacobian Sur ; }
                Integral { [ - Vector[0.,0.,1.] * (((Dof{hi_1})/H_tape) /\ normal_vector[]) , {j_ext_top~{i}} ] ;
                    In Region[{TS_down_aux_next~{i}}]; Integration Int ; Jacobian Sur ; }
                Integral { [ - Vector[0.,0.,1.] * (((-Dof{hi~{N_ele+1}})/H_tape) /\ normal_vector[]) , {j_ext_top~{i}} ] ;
                    In Region[{TS_down_aux_next~{i}}]; Integration Int ; Jacobian Sur ; }

                // bottom surface
                Integral { [ Dof{j_ext_bot~{i}} , {j_ext_bot~{i}} ] ;
                    In Region[{TS_up_aux~{i}}]; Integration Int ; Jacobian Sur ; }
                Integral { [ - Vector[0.,0.,1.] * (((-Dof{hi~{N_ele+1}})/H_tape) /\ normal_vector[]) , {j_ext_bot~{i}} ] ;
                    In Region[{TS_up_aux~{i}}]; Integration Int ; Jacobian Sur ; }
                Integral { [ - Vector[0.,0.,1.] * (((Dof{hi_1})/H_tape) /\ normal_vector[]) , {j_ext_bot~{i}} ] ;
                    In Region[{TS_down_aux~{i}}]; Integration Int ; Jacobian Sur ; }
            EndFor
        }
    }
}

Include "../lib/simple_resolution.pro";

PostProcessing {
    { Name MagDyn_hphits; 
        NameOfFormulation MagDyn_hphits_monolithic;
        PostQuantity {
            { Name phi; Value{ Local{ [ {dInv hr} ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name h; Value{ 
                Term{ [ {hr} + {hs} ]; In Omega; Jacobian Vol; }
                } 
            }
            { Name hs  ; Value { 
                Term{ [ {hs} ]; In OmegaCC; Jacobian Vol; }
                } 
            }
            { Name hsx  ; Value { 
                Term{ [ CompX[{hs}] ]; In OmegaCC; Jacobian Vol; }
                } 
            }
            { Name hsy  ; Value { 
                Term{ [ CompY[{hs}] ]; In OmegaCC; Jacobian Vol; }
                } 
            }
            { Name hr  ; Value { Term { [ {hr} ] ; Jacobian Vol ;
                In Omega ; } } }
            { Name js; Value { 
                Term{ [ {d hs} ]; In OmegaS; Jacobian Vol; }
                } 
            }
            { Name js_normalized; Value { 
                If(nb_eff_source_domains > 0)
                    Term{ [ {d hs} / my_fill_factor[] ]; In OmegaS; Jacobian Vol; }
                EndIf
                } 
            }
            { Name b; Value{ 
                Term{ [ mu[]*({hr}+{hs}) ]; In OmegaCC; Jacobian Vol; }
                } 
            }
            { Name b_norm; Value{ 
                Term{ [ Norm[mu[]*({hr}+{hs})] ]; In OmegaCC; Jacobian Vol; }
                } 
            }
            { Name dtb; Value{ 
                Term{ [ mu[]*Dt[{hr}+{hs}] ]; In OmegaCC; Jacobian Vol; }
                } 
            }

            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }

            { Name I ; Value { 
                For i In {1:nbConductors}
                    Term { [ {I~{i}} ] ;In Cut~{i} ; }
                EndFor
                } 
            }
            { Name V ; Value { 
                For i In {1:nbConductors}
                    Term { [ {V~{i}} ] ; In Cut~{i} ; }
                EndFor
                }
            }
            { Name Z ; Value { 
                For i In {1:nbConductors}
                    Term { [ {V~{i}} / {I~{i}} ] ; In Cut~{i} ; }
                EndFor
                } 
            }
            { Name dissPowerGlobal; Value { 
                For i In {1:nbConductors}
                    Term { [ {V~{i}} * {I~{i}} ] ; In Cut~{i} ; }
                EndFor
                } 
            }

            For i In {0:N_ele+1+1}
                { Name hi~{i}; Value{ Local{ [{hi~{i}}  ] ; // Magnetic field tangential component in each intermediary surface of the virtual representation
                In GammaTS~{(i<N_ele+1)? 0:1}; Jacobian Sur; } } }
                { Name jzi~{i}; Value{ Local{ [{d hi~{i}}  ] ;
                In GammaTS~{(i<N_ele+1)? 0:1}; Jacobian Sur; } } }
            EndFor

            For i In {1:N_ele+1-1}
                If(Flag_jcb)
                    { Name norm_jijc~{i}; Value{ Local{ [Norm[{hi~{i}}-{hi~{i+1}}] *1/Delta/jcb_TS[mu[]*({hi~{i}}+{hi~{i+1}})/2, {bn_perp}] ] ; // Norm of the relative current density in each virtual element
                    In GammaTS_0; Jacobian Sur; } } }

                    { Name jijc~{i}; Value{ Local{ [ {hi~{i}}*1/Delta/jcb_TS[mu[]*({hi~{i}}+{hi~{i+1}})/2, {bn_perp}] /\ -Normal[] -{hi~{i+1}}*1/Delta/jcb_TS[mu[]*({hi~{i}}+{hi~{i+1}})/2, {bn_perp}] /\ -Normal[]   ] ; // Current density vector in each virtual element
                    In GammaTS_0; Jacobian Sur; } } }
                Else
                    { Name norm_jijc~{i}; Value{ Local{ [Norm[{hi~{i}}-{hi~{i+1}}] *1/Delta/jc ] ; // Norm of the relative current density in each virtual element
                    In GammaTS_0; Jacobian Sur; } } }

                    { Name jijc~{i}; Value{ Local{ [ {hi~{i}}*1/Delta/jc /\ -Normal[] -{hi~{i+1}}*1/Delta/jc /\ -Normal[]   ] ; // Current density vector in each virtual element
                    In GammaTS_0; Jacobian Sur; } } }
                EndIf

                { Name norm_ji~{i}; Value{ Local{ [Norm[{hi~{i}}-{hi~{i+1}}] *1/Delta ] ; // Norm of the relative current density in each virtual element
                In GammaTS_0; Jacobian Sur; } } }

                { Name ji~{i}; Value{ Local{ [ {hi~{i}}*1/Delta /\ -Normal[] - {hi~{i+1}}*1/Delta /\ -Normal[]   ] ; // Current density vector in each virtual element
                In GammaTS_0; Jacobian Sur; } } }
            EndFor

            { Name norm_j_tot; Value{ Local{ [Norm[{hi_1}-{hi~{N_ele+1}}] *1/H_tape ] ;
                In GammaTS_0; Jacobian Sur; } } }

            { Name j_tot; Value{ Local{ [ ({hi_1} - {hi~{N_ele+1}}) *1/H_tape /\ normal_vector[] ] ;
                In GammaTS_0; Jacobian Sur; } } }
            
            { Name jz_tot; Value{ Local{ [ CompZ[({hi_1} - {hi~{N_ele+1}}) *1/H_tape /\ normal_vector[]] ] ;
                In GammaTS_0; Jacobian Sur; } } }

            { Name power; // (h+h[1])/2 instead of h -> to avoid a constant sign error accumulation
                Value{
                    Integral{ [ mu[]*({hr} + {hs} - ({hr}[1] + {hs}[1])) / $DTime * ({hr}+{hr}[1]+{hs}+{hs}[1])/2 ] ; // this decomposition is correct for h = hr + hs
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    For i In {1:N_ele} 
                        If(Flag_jcb)
                            Integral {
                                [ rho_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * {hi~{i}} * 1/Delta * {hi~{i}} ] ;
                                    In GammaTS_0  ; Jacobian Sur ; Integration Int ; }
                            Integral {
                                [ - 2 * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * {hi~{i}} * 1/Delta * {hi~{i+1}} ] ;
                                    In GammaTS_0  ; Jacobian Sur ; Integration Int ; }
                            Integral {
                                [ rho_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * {hi~{i+1}} * 1/Delta * {hi~{i+1}} ] ;
                                    In GammaTS_0  ; Jacobian Sur ; Integration Int ; }
                        Else
                            Integral {
                                [ rho_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * {hi~{i}} * 1/Delta * {hi~{i}} ] ;
                                    In GammaTS_0  ; Jacobian Sur ; Integration Int ; }
                            Integral {
                                [ - 2 * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * {hi~{i}} * 1/Delta * {hi~{i+1}} ] ;
                                    In GammaTS_0  ; Jacobian Sur ; Integration Int ; }
                            Integral {
                                [ rho_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * {hi~{i+1}} * 1/Delta * {hi~{i+1}} ] ;
                                    In GammaTS_0  ; Jacobian Sur ; Integration Int ; }
                        EndIf
                    EndFor
                }
            }

            { Name dissPower ; // Instantaneous AC losses in the tape
                Value {
                    For i In {1:N_ele}
                        If(Flag_jcb)
                            Integral {
                                [ rho_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * {hi~{i}} * 1/Delta * {hi~{i}} ] ;
                                    In GammaTS_0  ; Jacobian Sur ; Integration Int ; }
                            Integral {
                                [ - 2 * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * {hi~{i}} * 1/Delta * {hi~{i+1}} ] ;
                                    In GammaTS_0  ; Jacobian Sur ; Integration Int ; }
                            Integral {
                                [ rho_power_TS_built_in[{hi~{i}},{hi~{i+1}},{bn_perp}] * {hi~{i+1}} * 1/Delta * {hi~{i+1}} ] ;
                                    In GammaTS_0 ; Jacobian Sur ; Integration Int ; }
                        Else
                            Integral {
                                [ rho_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * {hi~{i}} * 1/Delta * {hi~{i}} ] ;
                                    In GammaTS_0  ; Jacobian Sur ; Integration Int ; }
                            Integral {
                                [ - 2 * rho_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * {hi~{i}} * 1/Delta * {hi~{i+1}} ] ;
                                    In GammaTS_0  ; Jacobian Sur ; Integration Int ; }
                            Integral {
                                [ rho_power_TS_built_in[{hi~{i}},{hi~{i+1}}] * {hi~{i+1}} * 1/Delta * {hi~{i+1}} ] ;
                                    In GammaTS_0 ; Jacobian Sur ; Integration Int ; }
                        EndIf
                    EndFor
                    For i In {1:nb_eff_source_domains}
                        Integral { [ rho_hom_power[eff_fill_factor * (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}}) * Vector[0,0,1],mu[]*({hr}+{hs})] * SquNorm[eff_fill_factor * (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}})] ] ;
                            In OmegaS~{i} ; Jacobian Vol ; Integration Int ; }
                    EndFor
                }
            }

            { Name jsz; Value{ 
                For i In {1:nb_eff_source_domains}
                    Term{ [ my_fill_factor[] * (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}}) ]; In OmegaS~{i}; Jacobian Vol; }
                EndFor
                } 
            }
            { Name jsz_jc; Value{ 
                For i In {1:nb_eff_source_domains}
                    Term{ [ (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}}) / (jcb[mu[]*({hr}+{hs})]) ]; In OmegaS~{i}; Jacobian Vol; }
                EndFor
                } 
            }
            { Name jsz_normalized; Value{ 
                For i In {1:nb_eff_source_domains}
                    Term{ [ (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}}) ]; In OmegaS~{i}; Jacobian Vol; }
                EndFor
                } 
            }
            { Name by; Value{ 
                    Term{ [ CompY[mu[]*({hr} + {hs})] ]; In OmegaCC; Jacobian Vol; }
                } 
            }
            If(Flag_jcb)
                { Name b_perp; Value{ 
                        Term{ [ {bn_perp} ]; In GammaTS; Jacobian Sur; }
                    } 
                }
            EndIf
        }
    }
    { Name js_proj_postpro; 
        NameOfFormulation MagDyn_hphits_monolithic;
        Quantity {
            { Name Is_integral ; // integrated current
                Value{
                    For i In {1:nb_eff_source_domains}
                        Integral{ [ Vector[0,0,1] * my_fill_factor[] * (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}}) * UnitVectorZ[] ] ;
                                In OmegaS~{i} ; Integration Int ; Jacobian Vol; }
                    EndFor
                }
            }
            { Name Is_theoretical ; // theoretical source current
                Value {
                    For i In {1:nb_eff_source_domains}
                        Term { [ Is_modulation[] * Is_max~{i} ] ; In OmegaS~{i} ; Jacobian Vol ; }
                    EndFor
                }
            }
            { Name js_jc_interp; Value{ 
                For i In {1:nb_eff_source_domains}
                    Local{ [ (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}}) / (jcb[mu[]*({hr}+{hs})]) ] ; In OmegaS~{i}; Jacobian Vol; } 
                EndFor
            } }
        }
    }
}

// ----------------------------------------------------------------------------
// --------------------------- POST-OPERATION ---------------------------------
// ----------------------------------------------------------------------------
// NB: we might win some time if we do not print the indicators in the dummy.txt file, same for the resolution itself ...
// Operations useful for convergence criterion
PostOperation {
    // Extracting energetic quantities
    { Name MagDyn_energy ; LastTimeStepOnly 1 ;
        NameOfPostProcessing MagDyn_hphits;
        Operation{
            Print[ dissPower[NonLinOmegaC], OnGlobal, Format Table, StoreInVariable $indicDissSuper, File > "res/dummy.txt" ];
        }
    }
    { Name MagDyn_energy_full ; LastTimeStepOnly 1 ;
        NameOfPostProcessing MagDyn_hphits;
        Operation{
            Print[ power[Air], OnGlobal, Format TimeTable, StoreInVariable $indicAir, File StrCat[outputDirectory,"/powerAIR.txt"]];
            Print[ dissPower[NonLinOmegaC], OnGlobal, Format TimeTable, StoreInVariable $indicDissSuper, File StrCat[outputDirectory,"/powerNONLINOMEGAC.txt"]];
        }
    }
    { Name detailedPower ; LastTimeStepOnly 1 ;
        NameOfPostProcessing MagDyn_hphits;
        Operation{
            For i In {1:nbConductors}
                Print[ dissPower[GammaTS_0~{i}], OnGlobal, Format TimeTable, File > outputPowerCond~{i} ];
            EndFor
        }

    }
    // Runtime output for graph plot
    { Name Info;
        NameOfPostProcessing MagDyn_hphits ;
        Operation{
            Print[ time[OmegaC], OnRegion OmegaC, LastTimeStepOnly, Format Table, SendToServer "Output/0Time [s]"] ;
            Print[ I, OnRegion Cut_1, LastTimeStepOnly, Format Table, SendToServer "Output/1Applied current 1 [A]"] ;
            Print[ V, OnRegion Cut_1, LastTimeStepOnly, Format Table, SendToServer "Output/2Tension 1 [Vm^-1]"] ;
            Print[ I, OnRegion Cut_2, LastTimeStepOnly, Format Table, SendToServer "Output/1Applied current 2 [A]"] ;
            Print[ V, OnRegion Cut_2, LastTimeStepOnly, Format Table, SendToServer "Output/2Tension 2 [Vm^-1]"] ;
            Print[ dissPower[OmegaC], OnGlobal, LastTimeStepOnly, Format Table, SendToServer "Output/3Joule loss [W]"] ;
        }
    }
    { Name MagDyn;
        NameOfPostProcessing MagDyn_hphits ;
        Operation {
            Print[ phi, OnElementsOf OmegaCC , File "res/phi.pos", Name "phi [A]" ];
            For i In {1:nbConductors}
                Print[ I, OnRegion Cut~{i}, Format TimeTable, File StrCat[outputDirectory,Sprintf["/I_cond_%g.txt",i]] ];
                If(Flag_compute_voltage)
                    Print[ V, OnRegion Cut~{i}, Format TimeTable, File StrCat[outputDirectory,Sprintf["/V_cond_%g.txt",i]] ];
                EndIf
            EndFor
            Print[ h, OnElementsOf OmegaCC , File "res/h.pos", Name "h [A/m]" ];
            Print[ b, OnElementsOf Air , File "res/b.pos", Name "b [T]" ];
            Print[ hs, OnElementsOf OmegaCC , File "res/hs.pos", Name "hs [A/m]" ];
            Print[ hsx, OnElementsOf OmegaS , File "res/hsx.pos", Name "hsx [A/m]" ];
            Print[ hsy, OnElementsOf OmegaCC , File "res/hsy.pos", Name "hsy [A/m]" ];
            Print[ hr, OnElementsOf OmegaCC , File "res/hr.pos", Name "hr [A/m]" ];
            If(nb_eff_source_domains > 0)
                Print[ js, OnElementsOf OmegaS , File "res/js.pos", Name "js [A/m2]" ];
                Print[ js_normalized, OnElementsOf OmegaS , File "res/js_normalized.pos", Name "js/ff [-]" ];
            EndIf
            For i In {1:N_ele} // Normalized current density in each virtual element
                Print[ hi~{i}, OnElementsOf GammaTS_0, File Sprintf("res/h_%g.pos", i), Name Sprintf("h(%g)",i) ];
                Print[ jijc~{i}, OnElementsOf GammaTS_0, File Sprintf("res/j_jc_%g.pos", i), Name Sprintf("j_jc(%g)",i) ];
                Print[ ji~{i}, OnElementsOf GammaTS_0, File Sprintf("res/j_%g.pos", i), Name Sprintf("j(%g)",i) ];
            EndFor
            Print[ hi~{N_ele+1}, OnElementsOf GammaTS_1, File Sprintf("res/h_%g.pos", N_ele+1), Name Sprintf("h(%g)",N_ele+1) ];
            Print[ norm_j_tot, OnElementsOf GammaTS_0, File "res/norm_j_tot.pos", Name "norm_j_tot" ];
            Print[ j_tot, OnElementsOf GammaTS_0, File "res/j_tot.pos", Name "j_tot" ];
            Print[ b_norm, OnElementsOf OmegaCC, File "res/b_norm.pos", Name "b_norm [T]" ];
            Print[ by, OnElementsOf OmegaCC, File "res/by.pos", Name "by [T]" ];
            If(Flag_jcb)
                Print[ b_perp, OnElementsOf GammaTS_0, File "res/b_perp_bot.pos", Name "b_perp_bot [T]" ];
            EndIf
            If(nb_eff_source_domains > 0)
                Print[ jsz, OnElementsOf OmegaS, File "res/jsz.pos", Name "jsz [A/m2]" ];
                Print[ jsz_normalized, OnElementsOf OmegaS, File "res/jsz_normalized.pos", Name "jsz/ff [-]" ];
            EndIf

        }
    }
    // useful for checking integral of js over OmegaS~{i} gives Is_tot[]
    { Name MapProj_Is_check; LastTimeStepOnly 1 ;
        NameOfPostProcessing js_proj_postpro ;
        Operation {
            For i In {1:nb_eff_source_domains}
                Print[ Is_integral[OmegaS~{i}], OnGlobal, Format Table, StoreInVariable $Is~{i}, File Sprintf["res/dummy_Is_%g.txt", i]];
                Print[ Is_theoretical[Cut_source~{i}], OnRegion OmegaS~{i}, Format Table, StoreInVariable $Is_th~{i}, File > Sprintf["res/dummy_Is_%g_2.txt", i] ];
            EndFor
        }
    }
    { Name J_distrib;
        NameOfPostProcessing MagDyn_hphits;
        TimeValue {0:0.02:0.0001};
        Operation {
            For i In {1:num_pancakes}
                For j In {1:num_analyzed_tapes}
                    Print[ jz_tot, OnElementsOf GammaTS_0~{nbConductors_per_pancake*(i-1)+j}, Depth 0, File Sprintf["test_j/j_%g_%g.txt",i,j], Format TimeTable ];
                EndFor
            EndFor
        }
    }
}

DefineConstant[
  R_ = {"MagDyn", Name "GetDP/1ResolutionChoices", Visible 0},
  C_ = {"-solve -pos -bin -v 3 -v2", Name "GetDP/9ComputeCommand", Visible 0},
  P_ = { "MagDyn", Name "GetDP/2PostOperationChoices", Visible 0}
];
