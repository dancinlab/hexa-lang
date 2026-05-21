Include "../common/pancakes_data.pro";
Include "../lib/commonInformation.pro";

// simultaneous multi-scale t-a thin-shell formulation for stacked pancakes
// see E. Berrospe et al., SUST, 2021 for simultaneous multi-scale method


Group {
    // ------- PROBLEM DEFINITION -------
    name = "pancakes_smsts_ta/";

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
    Cond = Region[{}]; // for t-a formulation
    For i In {1:nbConductors}
        Cond += Region[ (TS + TS_OFFSET*(i-1)) ];
        BndOmegaC += Region[ (TS + TS_OFFSET*(i-1)) ];
        Cut~{i} = Region[ (THICK_CUT + (i-1)) ]; // for imposing the net current

        GammaTS_1 += Region[ (TS_UP + TS_OFFSET*(i-1)) ];
        GammaTS_0 += Region[ (TS_DOWN + TS_OFFSET*(i-1)) ];

        GammaTS_0~{i} = Region[ (TS_DOWN + TS_OFFSET*(i-1)) ]; // useful for computing the ac losses in each conductor separately

        TS_EdgeLeft += Region[ (TS_EDGE_LEFT + TS_OFFSET*(i-1)) ];
        TS_EdgeRight += Region[ (TS_EDGE_RIGHT + TS_OFFSET*(i-1)) ];

        TS_EdgeRight~{i} = Region[ (TS_EDGE_RIGHT + TS_OFFSET*(i-1)) ]; // useful for imposing different boundary conditions on each conductor in TA formulation
        TS~{i} = Region[ (TS + TS_OFFSET*(i-1)) ]; // useful for computing the ac losses in each conductor separately
    EndFor
    GammaTS = Region[{GammaTS_0, GammaTS_1}];
    TS_LateralEdges = Region[ {TS_EdgeLeft, TS_EdgeRight} ];

    OmegaS = Region[ {} ]; // contains all source domains
    BndOmegaS = Region[ {} ]; // contains all boundaries of source domains
    eff_source_dom_ID = 0; // will be incremented in next loop (counting number of effective source domains we've gone through)
    For i In {1:num_pancakes}
        // some book-keeping
        AirTS_Down~{(i-1)*num_analyzed_tapes+1} = Region[{Air~{i}}]; // first air below first tape
        AirTS_Up~{(i-1)*num_analyzed_tapes+num_analyzed_tapes} = Region[{Air~{i}}]; // last air above last tape
        For j In {1:nb_source_domains_per_pancake}
            AirAux~{nb_source_domains_per_pancake*(i-1)+j} = Region[ (BULK+BULK_OFFSET*(num_analyzed_tapes-1)*(i-1) + BULK_OFFSET * (j-1) - 1) ]; // air between tapes
            Air~{i} += Region[ {AirAux~{nb_source_domains_per_pancake*(i-1)+j}} ]; // filling air domain

            AirTS_Up~{(i-1)*num_analyzed_tapes+j} = Region[{AirAux~{nb_source_domains_per_pancake*(i-1)+j}}]; // air above tape j
            AirTS_Down~{(i-1)*num_analyzed_tapes+j+1} = Region[{AirAux~{nb_source_domains_per_pancake*(i-1)+j}}]; // air below tape j+1
            // check if we are in an effective source domain.
            If(eff_source_dom_ID < nb_eff_source_domains && is_eff_source_dom~{nb_source_domains_per_pancake*(i-1)+j} == 1)
                eff_source_dom_ID += 1;

                OmegaS~{eff_source_dom_ID} = Region[ (BULK+BULK_OFFSET*nb_source_domains_per_pancake*(i-1) + BULK_OFFSET*(j-1)) ]; // one per source domain.
                OmegaS += Region[ {OmegaS~{eff_source_dom_ID}} ];
                // ! for BndOmegaS~{i} we must manually add the correct boundaries, knowing that the mesh entity of each bulk domain contains only the lower parts of the cracks (the bottom lower part must be replaced by the corresponding upper part)
                BndOmegaS~{eff_source_dom_ID} = Region[ (BND_BULK+BULK_OFFSET*nb_source_domains_per_pancake*(i-1) + BULK_OFFSET*(j-1)) ];

                BndOmegaS += Region[ {BndOmegaS~{eff_source_dom_ID}} ];

                Cut_source~{eff_source_dom_ID} = Region[ (CUT_SOURCE+nb_eff_source_domains/num_pancakes*(i-1) + j - 1) ];

                AirAroundSource~{eff_source_dom_ID} = Region[ {AirAux~{nb_source_domains_per_pancake*(i-1)+j}} ]; // useful for definition of js fields

                // for t-a formulation
                TS_current~{eff_source_dom_ID} = Region[ (TS + TS_OFFSET*(num_analyzed_tapes*(i-1)+j-1)) ];
                TS_next~{eff_source_dom_ID} = Region[ (TS + TS_OFFSET*(num_analyzed_tapes*(i-1)+j)) ];
            EndIf
        EndFor
    EndFor

    For i In {1:num_pancakes}
        Air += Region[ {Air~{i}} ]; // filling air domain
    EndFor

    // Fill the regions for formulation
    MagnLinDomain = Region[ {Air} ];
    NonLinOmegaC = Region[ {Cond} ];

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
    formulation = 7; // SMSTS-ta: formulation = 7
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
                my_fill_factor[Region[{OmegaS~{eff_source_dom_ID}}]] = H_tape / d_btw_tapes;

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
    For i In {1:num_pancakes} 
        For j In {1:nbConductors_per_pancake}
            { Name Current~{nbConductors_per_pancake*(i-1)+j} ; Type Assign;
                Case {
                    { Region TS_EdgeRight~{nbConductors_per_pancake*(i-1)+j}; Value 1.0; TimeFunction I[]; } // t_tilde = w t
                }
            }
            { Name Voltage~{nbConductors_per_pancake*(i-1)+j} ; Case { } } // for h-phi-form
        EndFor
    EndFor

    For i In {1:nb_eff_source_domains}
        { Name Bottom_extrusion~{i};
            Case {
                { Region OmegaS~{i}; Type Link ; RegionRef TS_current~{i};
                    Coefficient 1; Function Vector[$X,Y_bottom~{i},$Z];
                }
            }
        }
        { Name Top_extrusion~{i};
            Case {
                { Region OmegaS~{i}; Type Link ; RegionRef TS_next~{i};
                    Coefficient 1; Function Vector[$X,Y_top~{i},$Z];
                }
            }
        }
    EndFor

    { Name a ;
        Case {
            {Region SurfOut ; Value 0.0;}
        }
    }

}

Include "../lib/jac_int.pro";

FunctionSpace {
    For i In {1:nb_eff_source_domains}
        { Name j_extruded_bottom_space~{i}; Type Form0 ;
            BasisFunction {
                { Name psi_j_ext_bot_n~{i} ; NameOfCoef j_ext_bot_n~{i} ; Function BF_Node ;
                Support Region[{OmegaS~{i},AirAroundSource~{i},TS_current~{i}}] ; Entity NodesOf[{OmegaS~{i}, AirAroundSource~{i}}] ; }
            }
            Constraint {
                { NameOfCoef j_ext_bot_n~{i};
                EntityType NodesOf; NameOfConstraint Bottom_extrusion~{i}; }
            }
        }
        { Name j_extruded_top_space~{i}; Type Form0 ;
            BasisFunction {
                { Name psi_j_ext_top_n~{i} ; NameOfCoef j_ext_top_n~{i} ; Function BF_Node ;
                Support Region[{OmegaS~{i},AirAroundSource~{i},TS_next~{i}}] ; Entity NodesOf[{OmegaS~{i}, AirAroundSource~{i}}] ; }
            }
            Constraint {
                { NameOfCoef j_ext_top_n~{i};
                EntityType NodesOf; NameOfConstraint Top_extrusion~{i}; }
            }
        }
    EndFor

    { Name a_space_2D; Type Form1P;
        BasisFunction {
            { Name psin; NameOfCoef an; Function BF_PerpendicularEdge;
                Support Omega_a_AndBnd; Entity NodesOf[All]; }
            { Name psin2; NameOfCoef an2; Function BF_PerpendicularEdge_2E;
                Support Omega_a_AndBnd; Entity EdgesOf[{BndOmega_ha}]; }
        }
        Constraint {
            { NameOfCoef an; EntityType NodesOf; NameOfConstraint a; }
        }
    }
    // Function space for the current vector potential in t-a-formulation
    // The function here is the normal component of the vector t. The normal direction is
    // introduced explicitly in the formulation, where the "true t" is Dof{t} * normal_vector[]
    //
    //  t = sum phi_n * psi_n     (nodes inside the tape)
    //      + sum T_i * psi_i     (global shape function linked to current intensity)
    //
    // NB: psi_i makes sense as a "global function" only in 3D. In 2D, this is simply one nodal function
    //      at the positive edge of the tape, but with the syntax below, all situations are treated the same way.
    { Name t_space; Type Form0;
        BasisFunction {
            { Name psin; NameOfCoef tn; Function BF_Node;
                Support Omega_h; Entity NodesOf[All, Not TS_LateralEdges]; } // = 0 on lateral edges
            For i In {1:nbConductors}
                { Name psi; NameOfCoef Ti~{i}; Function BF_GroupOfNodes;
                    Support Omega_h_OmegaC_AndBnd; Entity GroupsOfNodesOf[TS_EdgeRight~{i}]; }
            EndFor
        }
        GlobalQuantity {
            For i In {1:nbConductors}
                { Name T~{i} ; Type AliasOf        ; NameOfCoef Ti~{i} ; }
                { Name V~{i} ; Type AssociatedWith ; NameOfCoef Ti~{i} ; }
            EndFor
        }
        Constraint {
            For i In {1:nbConductors}
                { NameOfCoef V~{i} ;
                    EntityType GroupsOfNodesOf ; NameOfConstraint Voltage~{i} ; }
                { NameOfCoef T~{i} ;
                    EntityType GroupsOfNodesOf ; NameOfConstraint Current~{i} ; }
            EndFor
        }
    }

    // trick to retrieve tangential component of b on thin-shell (otherwise not obtained when evaluating {d a} on thin-shell, exclusively along normal). here b_tan is aligned along normal, but we will rotate it explicitely in weak form
    { Name b_tan_TS_space ; Type Form2;
        BasisFunction {
            { Name psif_tot; NameOfCoef b_tan_f; Function BF_PerpendicularFacet;
                Support Region[{OmegaCC,Cond}]; Entity EdgesOf[Cond]; }
        }
    }
}

Formulation {
    { Name MagDyn_ta_monolithic; Type FemEquation;
        Quantity {
            { Name t; Type Local; NameOfSpace t_space; }
            For i In {1:nbConductors}
                { Name T~{i}; Type Global; NameOfSpace t_space[T~{i}]; }
                { Name V~{i}; Type Global; NameOfSpace t_space[V~{i}]; }
            EndFor
            { Name a; Type Local; NameOfSpace a_space_2D; }
            For i In {1:nb_eff_source_domains}
                { Name j_ext_bot~{i}; Type Local; NameOfSpace j_extruded_bottom_space~{i}; }
                { Name j_ext_top~{i}; Type Local; NameOfSpace j_extruded_top_space~{i}; }
            EndFor
            If(Flag_jcb)
                { Name b_tan; Type Local; NameOfSpace b_tan_TS_space; }
            EndIf
        }
        Equation {
            // PART 1: T-A FORMULATION
            Galerkin { DtDof[ normal_vector[] /\ Dof{a} , {d t} ];
                In OmegaC; Integration Int; Jacobian Sur;  }
            // ---- SUPER ----
            // Induced currents
            If(Flag_jcb)
                Galerkin { [ 1./H_tape * rho_power_built_in[1./H_tape *{d t} /\ normal_vector[], {d a} + UnitVectorX[] * (UnitVectorY[] * {b_tan}) ] * normal_vector[] /\ (Dof{d t} /\ normal_vector[]) , {d t} ]; // rotation of b_tan from y orientation to x orientation
                    In NonLinOmegaC; Integration Int; Jacobian Sur;  }
                Galerkin { JacNL[ 1./H_tape * normal_vector[] /\ (drhodj_timesj_power_built_in[1./H_tape *{d t} /\ normal_vector[], {d a} + UnitVectorX[] * (UnitVectorY[] * {b_tan}) ] * (Dof{d t} /\ normal_vector[])) , {d t} ];
                    In NonLinOmegaC; Integration Int; Jacobian Sur;  }
            Else
                Galerkin { [ 1./H_tape * rho_power_built_in[1./H_tape *{d t} /\ normal_vector[], {d a} ] * normal_vector[] /\ (Dof{d t} /\ normal_vector[]) , {d t} ];
                    In NonLinOmegaC; Integration Int; Jacobian Sur;  }
                Galerkin { JacNL[ 1./H_tape * normal_vector[] /\ (drhodj_timesj_power_built_in[1./H_tape *{d t} /\ normal_vector[], {d a}] * (Dof{d t} /\ normal_vector[])) , {d t} ];
                    In NonLinOmegaC; Integration Int; Jacobian Sur;  }
            EndIf

            For i In {1:nbConductors}
                GlobalTerm { [ Dof{V~{i}} , {T~{i}} ] ; In TS_EdgeRight~{i} ; }
            EndFor
            // Curl h term - NonMagnDomain
            Galerkin { [ nu[] * Dof{d a} , {d a} ];
                In Omega_a; Integration Int; Jacobian Vol; }
            // Surface term
            Galerkin { [ - Dof{d t} /\ normal_vector[] , {a}]; // Dof{d t} /\ normal_vector[] is the current density!
                In BndOmega_ha; Integration Int; Jacobian Sur; }

            // Source terms
            For i In {1:nb_eff_source_domains}
                Galerkin { [ - Vector[0,0,1] * my_fill_factor[] * theta_bottom[] * Dof{j_ext_bot~{i}} , {a} ];
                    In OmegaS~{i}; Integration Int; Jacobian Vol; }
                Galerkin { [ - Vector[0,0,1] * my_fill_factor[] * theta_top[] * Dof{j_ext_top~{i}} , {a} ];
                    In OmegaS~{i}; Integration Int; Jacobian Vol; }
            EndFor

            If(Flag_jcb) 
                Galerkin {  [ Dof{b_tan}, {b_tan} ];
                    In Cond; Integration Int; Jacobian Sur;} 
                // most consistent is to split the trace evaluation in two integrals (on both sides of each thin-shell). Requires some book-keeping though, but works nicely.
                For i In {1:nbConductors}
                    Galerkin { [ - 0.5 * UnitVectorY[] * (UnitVectorX[] * Trace[ Dof{d a} , ElementsOf[AirTS_Up~{i}, ConnectedTo TS~{i}] ]) , {b_tan} ] ; In TS~{i}; Integration Int; Jacobian Sur;}
                    Galerkin { [ - 0.5 * UnitVectorY[] * (UnitVectorX[] * Trace[ Dof{d a} , ElementsOf[AirTS_Up~{i}, ConnectedTo TS~{i}] ]) , {b_tan} ] ; In TS~{i}; Integration Int; Jacobian Sur;}
                EndFor
            EndIf

            // PART 2: JSZ FORMULATION (linear interpolation)
            For i In {1:nb_eff_source_domains}
                Integral { [ Dof{j_ext_top~{i}} , {j_ext_top~{i}} ] ;
                    In Region[{TS_next~{i}}]; Integration Int ; Jacobian Sur ; }
                Integral { [ - Vector[0.,0.,1.] * 1./H_tape * (Dof{d t} /\ normal_vector[]) , {j_ext_top~{i}} ] ;
                    In Region[{TS_next~{i}}]; Integration Int ; Jacobian Sur ; }

                Integral { [ Dof{j_ext_bot~{i}} , {j_ext_bot~{i}} ] ;
                    In Region[{TS_current~{i}}]; Integration Int ; Jacobian Sur ; }
                Integral { [ - Vector[0.,0.,1.] * 1./H_tape * (Dof{d t} /\ normal_vector[]) , {j_ext_bot~{i}} ] ;
                    In Region[{TS_current~{i}}]; Integration Int ; Jacobian Sur ; }
            EndFor
        }
    }
}

Include "../lib/simple_resolution.pro";

PostProcessing {
    { Name MagDyn_ta; NameOfFormulation MagDyn_ta_monolithic;
    Quantity {
        { Name h; Value {
            Term { [ nu[] * {d a} ] ; In MagnLinDomain; Jacobian Vol; }
            }
        }
        { Name b; Value{
            Term { [ {d a} ] ; In Omega_a; Jacobian Vol;} } }
        If(Flag_jcb)
            { Name b_TS; Value{
                Term { [ {d a} + UnitVectorX[] * (UnitVectorY[] * {b_tan}) ] ; In Cond; Jacobian Sur;} } }
        Else
            { Name b_TS; Value{
                Term { [ {d a} ] ; In Cond; Jacobian Sur;} } }
        EndIf
        { Name b_norm; Value{
            Term { [ Norm[{d a}] ] ; In Omega_a; Jacobian Vol;} } }
        { Name by; Value{
            Term { [ CompY[{d a}]*Vector[0,1,0] ] ; In Omega_a; Jacobian Vol;} } }
        { Name a; Value{ Local{ [ {a} ] ;
            In Omega_a_AndBnd; Jacobian Vol; } } }
        // { Name hxn; Value{ Local{ [ normal_vector[] /\ {h} ] ;
        //    In Bnd; Jacobian Sur; } } }
        { Name compz_a; Value{ Local{ [ CompZ[{a}] ] ;
            In OmegaCC; Jacobian Vol; } } }
        { Name normal; Value{ Local{ [ normal_vector[] ] ;
            In OmegaC; Jacobian Sur; } } }
        // { Name j; Value{ Local{ [ 1./H_tape * {d t} /\ normal_vector[] ] ;
        //    In Omega; Jacobian Sur; } } }
        { Name j; Value{ Local{ [ 1./H_tape * {d t} /\ normal_vector[] ] ;
            In Omega; Jacobian Sur; } } }
        { Name jz_tot; Value{ Local{ [ 1./H_tape * ({d t} /\ normal_vector[]) * UnitVectorZ[] ] ;
            In Omega; Jacobian Sur; } } }
        { Name t; Value{ Local{ [ 1./H_tape * {t} * normal_vector[] ] ;
            In OmegaC; Jacobian Sur; } } }
        { Name tNorm; Value{ Local{ [ 1./H_tape * {t} ] ;
            In OmegaC; Jacobian Sur; } } }
        If(Flag_jcb)
            { Name e; Value{ Local{ [ 1./H_tape * rho_power_built_in[ 1./H_tape * {d t} /\ normal_vector[], {d a} + UnitVectorX[] * (UnitVectorY[] * {b_tan}) ]*{d t} /\ normal_vector[] ] ;
                In OmegaC; Jacobian Sur; } } }
            { Name jouleLosses; Value{ Local{ [ (1./H_tape * {d t} /\ normal_vector[]) * (1./H_tape * rho_power_built_in[ 1./H_tape * {d t} /\ normal_vector[], {d a} + UnitVectorX[] * (UnitVectorY[] * {b_tan}) ]*{d t} /\ normal_vector[]) ] ;
                In OmegaC; Jacobian Sur; } } }
        Else
            { Name e; Value{ Local{ [ 1./H_tape * rho_power_built_in[ 1./H_tape * {d t} /\ normal_vector[], {d a} ]*{d t} /\ normal_vector[] ] ;
                In OmegaC; Jacobian Sur; } } }
            { Name jouleLosses; Value{ Local{ [ (1./H_tape * {d t} /\ normal_vector[]) * (1./H_tape * rho_power_built_in[ 1./H_tape * {d t} /\ normal_vector[], {d a} ]*{d t} /\ normal_vector[]) ] ;
                In OmegaC; Jacobian Sur; } } }
        EndIf
        { Name jz; Value{ Local{ [ 1./H_tape * CompZ[{d t} /\ normal_vector[]] ] ;
            In OmegaC; Jacobian Sur; } } }
        { Name norm_j; Value{ Local{ [ 1./H_tape * Norm[{d t} /\ normal_vector[]] ] ;
            In OmegaC; Jacobian Sur; } } }
        { Name time; Value{ Term { [ $Time ]; In Omega; } } }
        { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }
        { Name power;
            Value{
                Integral{ [ ({d a} - {d a}[1]) / $DTime * nu[] * ({d a}+{d a}[1])/2 ] ;
                    In Air ; Integration Int ; Jacobian Vol; }
                Integral{ [ H_tape*({d a} - {d a}[1]) / $DTime * nu[] * {d a} ] ;
                    In OmegaC ; Integration Int ; Jacobian Sur; }
                If(Flag_jcb)
                    Integral{ [ 1./H_tape * rho_power_built_in[1./H_tape * {d t} /\ normal_vector[], {d a} + UnitVectorX[] * (UnitVectorY[] * {b_tan}) ]*{d t}*{d t}] ;
                    In OmegaC ; Integration Int ; Jacobian Sur; }
                Else
                    Integral{ [ 1./H_tape * rho_power_built_in[1./H_tape * {d t} /\ normal_vector[], {d a} ]*{d t}*{d t}] ;
                    In OmegaC ; Integration Int ; Jacobian Sur; }
                EndIf
            }
        }
        { Name dissPower;
            Value{
                If(Flag_jcb)
                    Integral{ [ 1./H_tape * rho_power_built_in[ 1./H_tape * {d t} /\ normal_vector[], {d a} + UnitVectorX[] * (UnitVectorY[] * {b_tan}) ]*{d t}*{d t}] ;
                    In OmegaC ; Integration Int ; Jacobian Sur; }
                Else
                    Integral{ [ 1./H_tape * rho_power_built_in[ 1./H_tape * {d t} /\ normal_vector[], {d a} ]*{d t}*{d t}] ;
                    In OmegaC ; Integration Int ; Jacobian Sur; }
                EndIf
                For i In {1:nb_eff_source_domains}
                    Integral { [ rho_hom_power[my_fill_factor[] * (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}}) * Vector[0,0,1], {d a}] * SquNorm[my_fill_factor[] * (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}})] ] ;
                        In OmegaS~{i} ; Jacobian Vol ; Integration Int ; }
                EndFor
            }
        }
        { Name V;
            Value{
                For i In {1:nbConductors}
                    Term{ [ {V~{i}} ] ; In TS_EdgeRight~{i};}
                EndFor
            }
        }
        { Name I;
            Value{
                For i In {1:nbConductors}
                    Term{ [ {T~{i}} ] ; In TS_EdgeRight~{i};}
                EndFor
            }
        }
        { Name dissPowerGlobal;
            Value{
                For i In {1:nbConductors}
                    Term{ [ H_tape * {T~{i}} * {V~{i}} ] ; In TS_EdgeRight~{i};}
                EndFor
            }
        }
        If(nb_eff_source_domains > 0)
            { Name js; Value { 
                For i In {1:nb_eff_source_domains}
                    Term{ [ UnitVectorZ[] * my_fill_factor[] * (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}}) ]; In OmegaS~{i}; Jacobian Vol; }
                EndFor
                } 
            }
            { Name jsz; Value{ 
                For i In {1:nb_eff_source_domains}
                    Term{ [ my_fill_factor[] * (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}}) ]; In OmegaS~{i}; Jacobian Vol; }
                EndFor
                } 
            }
        EndIf
    }
}
    If(nb_eff_source_domains > 0)
        { Name js_proj_postpro; 
            NameOfFormulation MagDyn_ta_monolithic;
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
                { Name js_jc_interp; 
                    Value{ 
                        For i In {1:nb_eff_source_domains}
                            Local{ [ (theta_bottom[] * {j_ext_bot~{i}} + theta_top[] * {j_ext_top~{i}}) / (jcb[{d a}]) ] ; In OmegaS~{i}; Jacobian Vol; } 
                        EndFor
                    } 
                }
            }
        }
    EndIf
}

// ----------------------------------------------------------------------------
// --------------------------- POST-OPERATION ---------------------------------
// ----------------------------------------------------------------------------
// NB: we might win some time if we do not print the indicators in the dummy.txt file, same for the resolution itself ...
// Operations useful for convergence criterion
PostOperation {
    // Extracting energetic quantities
    { Name MagDyn_energy ; LastTimeStepOnly 1 ;
        NameOfPostProcessing MagDyn_ta;
        Operation{
            Print[ dissPower[NonLinOmegaC], OnGlobal, Format Table, StoreInVariable $indicDissSuper, File > "res/dummy.txt" ];
        }
    }
    { Name MagDyn_energy_full ; LastTimeStepOnly 1 ;
        NameOfPostProcessing MagDyn_ta;
        Operation{
            Print[ power[Air], OnGlobal, Format TimeTable, StoreInVariable $indicAir, File StrCat[outputDirectory,"/powerAIR.txt"]];
            Print[ dissPower[NonLinOmegaC], OnGlobal, Format TimeTable, StoreInVariable $indicDissSuper, File StrCat[outputDirectory,"/powerNONLINOMEGAC.txt"]];
        }
    }
    { Name detailedPower ; LastTimeStepOnly 1 ;
        NameOfPostProcessing MagDyn_ta;
        Operation{
            For i In {1:nbConductors}
                Print[ dissPower[TS~{i}], OnGlobal, Format TimeTable, File > outputPowerCond~{i} ];
            EndFor
            //Print[ dissPower[OmegaS], OnGlobal, Format TimeTable, File > StrCat[outputDirectory,"/powerOmegaS.txt"]];
        }

    }
    // Runtime output for graph plot
    { Name Info;
        NameOfPostProcessing MagDyn_ta ;
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
        NameOfPostProcessing MagDyn_ta ;
        Operation {
            For i In {1:nbConductors}
                Print[ I, OnRegion Cut~{i}, Format TimeTable, File StrCat[outputDirectory,Sprintf["/I_cond_%g.txt",i]] ];
                If(Flag_compute_voltage)
                    Print[ V, OnRegion Cut~{i}, Format TimeTable, File StrCat[outputDirectory,Sprintf["/V_cond_%g.txt",i]] ];
                EndIf
            EndFor
            Print[ h, OnElementsOf OmegaCC , File "res/h.pos", Name "h [A/m]" ];
            Print[ b, OnElementsOf Air , File "res/b.pos", Name "b [T]" ];
            Print[ b_TS, OnElementsOf Cond , File "res/bTS.pos", Name "b [T]" ];
            If(nb_eff_source_domains > 0)
                Print[ js, OnElementsOf OmegaS , File "res/js.pos", Name "js [A/m2]" ];
            EndIf
            Print[ j, OnElementsOf Cond, File "res/j.pos", Name "norm_j_tot" ];
            Print[ b_norm, OnElementsOf OmegaCC, File "res/b_norm.pos", Name "b_norm [T]" ];
            Print[ by, OnElementsOf OmegaCC, File "res/by.pos", Name "by [T]" ];
        }
    }
    { Name J_distrib;
        NameOfPostProcessing MagDyn_ta;
        TimeValue {0:0.02:0.0001};
        Operation {
            For i In {1:num_pancakes}
                For j In {1:num_analyzed_tapes}
                    Print[ jz_tot, OnElementsOf TS~{nbConductors_per_pancake*(i-1)+j}, Depth 0, File Sprintf["test_j/j_%g_%g.txt",i,j], Format TimeTable ];
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
