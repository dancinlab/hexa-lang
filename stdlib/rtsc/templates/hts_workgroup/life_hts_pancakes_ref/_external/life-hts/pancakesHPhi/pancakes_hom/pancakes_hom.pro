Include "../common/pancakes_data.pro";
Include "../lib/commonInformation.pro";

// this file implements the h-phi Vanilla homogenization method for stacked pancakes
// adapted from V. Zermeno et al., Journal of Applied Physics, 2013.

Group {
    // ------- PROBLEM DEFINITION -------
    // Test name - for output files
    name = "pancakes_hom/";
    DefineConstant [testname = StrCat["hphi_hom_", Sprintf["%g", num_pancakes], "_pancakes_", Sprintf["%g", num_tapes], "_tapes_", Sprintf["%g", num_blocks], "_blocks"]]; // Test name - for output files

    nbConductors = num_blocks * num_pancakes;

    Air = Region[ AIR ];
    For i In {1:num_pancakes}
        Air += Region[ (AIR + i) ];
    EndFor

    Cond = Region[{}];
    BndOmegaC = Region[{}];
    THICK_CUT = SURF_OUT+3*num_pancakes*num_blocks+1;
    For i In {1:nbConductors}
        Cond += Region[ (BULK + i) ];
        BndOmegaC += Region[ (BND_BULK + i) ];
        Block~{i} = Region[ (BULK + i) ];
        Cut~{i} = Region[ (THICK_CUT + (i-1)) ]; // for imposing the net current
    EndFor

    // Fill the regions for formulation
    MagnLinDomain = Region[ {Air} ];
    NonLinOmegaC = Region[ {Cond} ];
    Super = Region[ {Cond} ];

    LinOmegaC = Region[ {} ];
    OmegaC = Region[ {LinOmegaC, NonLinOmegaC} ];
    OmegaCC = Region[ {Air} ];
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
    formulation = 4; // h-phi hom = 4, full-h hom = 5
    If(full_h_form)
        formulation = 5;
    EndIf
    fill_factor = H_tape / H_turn;

    DefineConstant [try_ASM_before_MUMPS = 0]; // Try ASM before MUMPS (for debugging purposes)
    Flag_try_ASM_before_MUMPS = try_ASM_before_MUMPS;

    tol_rel = 1e-6; // Relative tolerance on nonlinear residual
    tol_abs = 4e-7; // Absolute tolerance on nonlinear residual

    If(full_h_form)
        tol_rel = 4e-5;
        tol_abs = 4e-7;
    EndIf

    rho[Air] = 1; //used only for full_h_form, as in Comsol
}

Include "../common/pancakes_functions.pro";

Constraint {
    { Name phi ;
        Case {
            {Region ArbitraryPoint ; Value 0.0;}
            {Region SurfSym; Value 0.0;}
        }
    }
    For i In {1:num_pancakes} // h-phi form: one different constraint per cut
        For j In {1:num_blocks}
            // localized cuts: each cut carries the current of all tapes below it
            { Name Current~{num_blocks*(i-1)+j} ; Type Assign;
                Case {
                    { Region Cut~{num_blocks*(i-1)+j}; Value j*num_tapes/num_blocks; TimeFunction I[]; }
                }
            }
            { Name Voltage~{num_blocks*(i-1)+j} ; Case { } } // Nothing
        EndFor
    EndFor
    { Name Current ; Type Assign; // for full-h form
        Case {
            For i In {1:nbConductors}
                { Region Block~{i}; Value num_tapes/num_blocks; TimeFunction I[]; }
            EndFor
        }
    }
    { Name Voltage ; Case { } } // for full-h form
    { Name h ; Type Assign;
        Case {
            {Region SurfSym; Value 0.0;}
        }
    }
}

Include "../lib/jac_int.pro";

FunctionSpace {
    // Function space for classical h-phi formulation
    { Name h_space; Type Form1;
        BasisFunction {
            { Name gradpsin; NameOfCoef phin; Function BF_GradNode;
                Support Omega_h_AndBnd; Entity NodesOf[{OmegaCC, BndOmegaC}]; } // caution: add BndOmegaC here when there is some boundary btwn blocks
            { Name psie; NameOfCoef he; Function BF_Edge;
                Support Omega_h_OmegaC_AndBnd; Entity EdgesOf[All, Not BndOmegaC]; }
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
        Constraint {
            { NameOfCoef phin; EntityType NodesOf; NameOfConstraint phi; }
            { NameOfCoef he; EntityType EdgesOf; NameOfConstraint h; } // for symmetry constraint
            For i In {1:nbConductors}
                { NameOfCoef Current~{i} ;
                    EntityType GroupsOfEdgesOf ; NameOfConstraint Current~{i} ; }
                { NameOfCoef Voltage~{i}  ;
                    EntityType GroupsOfEdgesOf ; NameOfConstraint Voltage~{i} ; }
            EndFor
        }
    }
    { Name hfull_space; Type Form1;
        BasisFunction {
            { Name psiee; NameOfCoef hee; Function BF_Edge; // modify the name of the basis function to avoid conflict with the other function space!
                Support Omega_h_AndBnd; Entity EdgesOf[All]; }
        }
        Constraint {
            { NameOfCoef hee; EntityType EdgesOf; NameOfConstraint h; } // for symmetry constraint
        }
    }
    // Gradient of Electric scalar potential (2D), courtesy Erik Schnaubelt
   { Name Hregion_u_2D; Type Form1P; 
        BasisFunction {
        { Name sr; NameOfCoef ur; Function BF_RegionZ;
            Support OmegaC; Entity OmegaC; }
        }
        GlobalQuantity {
        { Name U; Type AliasOf;        NameOfCoef ur; }
        { Name I; Type AssociatedWith; NameOfCoef ur; }
        }
        Constraint {
        { NameOfCoef U;
            EntityType Region; NameOfConstraint Voltage; }
        { NameOfCoef I;
            EntityType Region; NameOfConstraint Current; }
        }
    }

}

Formulation {
    { Name MagDyn_hphi; Type FemEquation;
        Quantity {
            { Name h; Type Local; NameOfSpace h_space; }
            { Name hp; Type Local; NameOfSpace h_space; }
            For i In {1:nbConductors}
                { Name I~{i}; Type Global; NameOfSpace h_space[Current~{i}]; }
                { Name V~{i}; Type Global; NameOfSpace h_space[Voltage~{i}]; }
            EndFor
        }
        Equation {
            // Time derivative of b (NonMagnDomain)
            Galerkin { DtDof[ mu[] * Dof{h} , {h} ];
                In Omega; Integration Int; Jacobian Vol;  }
            // Induced currents (Non-linear materials)
            Galerkin { [ rho_power_built_in[{d h}, mu0*{h}] * Dof{d h} , {d h} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { JacNL[ drhodj_timesj_power_built_in[{d h}, mu0*{h}] * Dof{d h} , {d hp} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            // Induced currents (Global variables)
            If(Flag_compute_voltage)
                For i In {1:nbConductors}
                    GlobalTerm { [ Dof{V~{i}} , {I~{i}} ] ; In Cut~{i} ; }
                EndFor
            EndIf
        }
    }
    // h full formulation
    { Name MagDyn_hfull; Type FemEquation;
        Quantity {
            { Name h; Type Local; NameOfSpace hfull_space; }
            { Name hp; Type Local; NameOfSpace hfull_space; }
            { Name ur; Type Local; NameOfSpace Hregion_u_2D; }
            { Name I; Type Global; NameOfSpace Hregion_u_2D[I]; }
            { Name U; Type Global; NameOfSpace Hregion_u_2D[U]; }
        }
        Equation {
            // Time derivative of b (NonMagnDomain)
            Galerkin { DtDof[ mu[] * Dof{h} , {h} ];
                In Omega; Integration Int; Jacobian Vol;  }
            Galerkin { [ rho_power_built_in[{d h}, mu0*{h}] * Dof{d h} , {d h} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { JacNL[ drhodj_timesj_power_built_in[{d h}, mu0*{h}] * Dof{d h} , {d hp} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            // Induced current (LinOmegaC)
            Galerkin { [ rho[] * Dof{d h} , {d h} ];
                In Air; Integration Int; Jacobian Vol;  }
            
            // lagrange multipliers for imposing current
            Galerkin { [- Dof{ur} , {d h} ];
                In OmegaC; Integration Int; Jacobian Vol;  }

            Galerkin { [Dof{d h}  , {ur} ];
                In OmegaC; Integration Int; Jacobian Vol;  }

            GlobalTerm { [- Dof{I} , {U} ]; In OmegaC; }
        }
    }
}

Include "../lib/simple_resolution.pro";

PostProcessing {
    { Name MagDyn_hphi; NameOfFormulation MagDyn_hphi;
        Quantity {
            { Name phi; Value{ Local{ [ {dInv h} ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name h; Value{ Local{ [ {h} ] ;
                In Omega; Jacobian Vol; } } }
            { Name hNorm; Value{ Local{ [ Norm[{h}] ] ;
                In Omega; Jacobian Vol; } } }
            { Name b; Value {
                Term { [ mu[] * {h} ] ; In MagnLinDomain; Jacobian Vol; }
                }
            }
            { Name j; Value{ Local{ [ {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name j_jc; Value{ Local{ [ {d h}/jcb[mu0*{h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name e; Value{ Local{ [ rho_power_built_in[{d h}, mu0*{h}] * {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jouleLosses; Value{ Local{ [ rho_power_built_in[{d h}, mu0*{h}] * {d h} * {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz; Value{ Local{ [ CompZ[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz_unscaled; Value{ Local{ [ CompZ[{d h}]/fill_factor ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz_jc; Value{ Local{ [ CompZ[{d h}]/jcb[mu0*{h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jx; Value{ Local{ [ CompX[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jy; Value{ Local{ [ CompY[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name norm_j; Value{ Local{ [ Norm[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }
            { Name power; // (h+h[1])/2 instead of h -> to avoid a constant sign error accumulation
                Value{
                    Integral{ [ mu[] * ({h} - {h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [rho_power_built_in[{d h}, mu0*{h} ]*{d h}*{d h}] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
            { Name V; Value { 
                For i In {1:nbConductors}
                    Term{ [ {V~{i}} ] ; In Cut~{i}; } 
                EndFor
                } 
            }
            { Name I; Value { 
                For i In {1:nbConductors}
                    Term{ [ {I~{i}} ] ; In Cut~{i}; } 
                EndFor
                } 
            }
            { Name dissPower;
                Value{
                    Integral{ [rho_power_built_in[{d h}, mu0*{h} ]*{d h}*{d h}] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
            { Name by; Value{ Local{ [ mu[]*normal_vector[]*CompY[{h}] ] ;
                In OmegaC; Jacobian Vol; } } }
        }
    }
    { Name MagDyn_hfull; NameOfFormulation MagDyn_hfull;
        Quantity {
            { Name h; Value{ Local{ [ {h} ] ;
                In Omega; Jacobian Vol; } } }
            { Name hNorm; Value{ Local{ [ Norm[{h}] ] ;
                In Omega; Jacobian Vol; } } }
            { Name b; Value {
                Term { [ mu[] * {h} ] ; In MagnLinDomain; Jacobian Vol; }
                }
            }
            { Name by; Value{ Local{ [ mu[]*normal_vector[]*CompY[{h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name j; Value{ Local{ [ {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name e; Value{ Local{ [ rho_power_built_in[{d h}, mu0*{h}] * {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jouleLosses; Value{ Local{ [ rho_power_built_in[{d h}, mu0*{h}] * {d h} * {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz; Value{ Local{ [ CompZ[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz_unscaled; Value{ Local{ [ CompZ[{d h}]/fill_factor ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz_jc; Value{ Local{ [ CompZ[{d h}]/jcb[mu0*{h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jx; Value{ Local{ [ CompX[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jy; Value{ Local{ [ CompY[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name norm_j; Value{ Local{ [ Norm[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }
            { Name power; // (h+h[1])/2 instead of h -> to avoid a constant sign error accumulation
                Value{
                    Integral{ [ mu[] * ({h} - {h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [rho_power_built_in[{d h}, mu0*{h} ]*{d h}*{d h}] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
            { Name dissPower;
                Value{
                    Integral{ [rho_power_built_in[{d h}, mu0*{h} ]*{d h}*{d h}] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
        }
    }
}
// ----------------------------------------------------------------------------
// --------------------------- POST-OPERATION ---------------------------------
// ----------------------------------------------------------------------------
PostOperation {
    // Extracting energetic quantities
    { Name MagDyn_energy ; LastTimeStepOnly 1 ;
        If(full_h_form == 0)
            NameOfPostProcessing MagDyn_hphi;
        Else
            NameOfPostProcessing MagDyn_hfull;
        EndIf
        Operation{
            Print[ dissPower[NonLinOmegaC], OnGlobal, Format Table, StoreInVariable $indicDissSuper, File > "res/dummy.txt" ];
        }
    }
    { Name MagDyn_energy_full ; LastTimeStepOnly 1 ;
        If(full_h_form == 0)
            NameOfPostProcessing MagDyn_hphi;
        Else
            NameOfPostProcessing MagDyn_hfull;
        EndIf
        Operation{
            Print[ power[Air], OnGlobal, Format TimeTable, StoreInVariable $indicAir, File StrCat[outputDirectory,"/powerAIR.txt"]];
            Print[ dissPower[NonLinOmegaC], OnGlobal, Format TimeTable, StoreInVariable $indicDissSuper, File StrCat[outputDirectory,"/powerNONLINOMEGAC.txt"]];
        }
    }
    { Name detailedPower ; LastTimeStepOnly 1 ;
        If(full_h_form == 0)
            NameOfPostProcessing MagDyn_hphi;
        Else
            NameOfPostProcessing MagDyn_hfull;
        EndIf
        Operation{
            For i In {1:nbConductors}
                Print[ dissPower[Block~{i}], OnGlobal, Format TimeTable, File outputPowerCond~{i} ];
            EndFor
        }

    }
    // Runtime output for graph plot
    { Name Info;
        If(full_h_form == 0)
            NameOfPostProcessing MagDyn_hphi;
        Else
            NameOfPostProcessing MagDyn_hfull;
        EndIf
        Operation{
            Print[ time[OmegaC], OnRegion OmegaC, LastTimeStepOnly, Format Table, SendToServer "Output/0Time [s]"] ;
            Print[ dissPower[OmegaC], OnGlobal, LastTimeStepOnly, Format Table, SendToServer "Output/3Joule loss [W]"] ;
        }
    }
    { Name MagDyn;
        If(full_h_form == 0)
            NameOfPostProcessing MagDyn_hphi;
        Else
            NameOfPostProcessing MagDyn_hfull;
        EndIf
        Operation {
            If(full_h_form == 0)
                Print[ phi, OnElementsOf OmegaCC , File "res/phi.pos", Name "phi [A]" ];
                Print[ j_jc, OnElementsOf OmegaC , File "res/j_jc.pos", Name "j_jc [-]" ];
                For i In {1:nbConductors}
                    Print[ I, OnRegion Cut~{i}, Format TimeTable, File StrCat[outputDirectory,Sprintf["/I_cond_%g.txt",i]] ];
                    If(Flag_compute_voltage)
                        Print[ V, OnRegion Cut~{i}, Format TimeTable, File StrCat[outputDirectory,Sprintf["/V_cond_%g.txt",i]] ];
                    EndIf
                EndFor
            EndIf
            Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h [A/m]" ];
            Print[ b, OnElementsOf Omega , File "res/b.pos", Name "b [T]" ];
            Print[ j, OnElementsOf OmegaC , File "res/j.pos", Name "j [A/m^2]" ];
            Print[ e, OnElementsOf OmegaC , File "res/e.pos", Name "e [V/m]" ];
            Print[ jz_jc, OnElementsOf OmegaC , File "res/jz_jc.pos", Name "jz_jc [A/m^2]" ];
            Print[ by, OnElementsOf OmegaC , File "res/by.pos", Name "by [T]" ];
        }
    }
    { Name J_distrib;
        If(full_h_form == 0)
            NameOfPostProcessing MagDyn_hphi;
        Else
            NameOfPostProcessing MagDyn_hfull;
        EndIf
        TimeValue {0:0.02:0.0001};
        Operation {
            For i In {1:num_pancakes}
                For j In {1:num_tapes}
                    Print[ jz_unscaled, OnGrid {W_turn * (i-1) + (W_turn - W_tape)/2 + W_tape/(2*j_nb_samples) + W_tape/j_nb_samples * $A, H_turn/2 + H_turn * (j-1), 0} { 0:j_nb_samples-1:1, 0, 0 }, File Sprintf["test_j/j_%g_%g.txt",i,j], Format TimeTable ];
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