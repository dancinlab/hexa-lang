Include "../common/pancakes_data.pro";
Include "../lib/commonInformation.pro";

// this file implements the h-phi foil winding formulation for stacked pancakes
// see L. Denis et al., IEEE TMag, 2025.

name = "pancakes_fw/";
DefineConstant [testname = StrCat["hphiFW_", Sprintf["%g", num_pancakes], "_pancakes_", Sprintf["%g", num_tapes], "_tapes"]];

Group {
    nbConductors = num_pancakes;
    Air = Region[ AIR ];
    For i In {1:num_pancakes}
        Air += Region[ (AIR + i) ];
    EndFor
    Cond = Region[{}];
    BndOmegaC = Region[{}];
    THICK_CUT = SURF_OUT+3*num_pancakes+1;
    For i In {1:nbConductors}
        Cond += Region[ (BULK + i) ];
        Cond~{i} = Region[ (BULK + i) ];
        BndOmegaC += Region[ (BND_BULK + i) ];
        Cut~{i} = Region[ (THICK_CUT + (i-1)) ]; // for imposing the net current
    EndFor
    
    Sur_Air  = Region[ SURF_OUT ];
    Sur_Sym  = Region[ {SURF_SYM_BOT, SURF_SYM_LEFT} ];
    Sur_Sym_h = Region[ SURF_SYM_BOT ];
    
    // Abstract regions
    Super = Region[{Cond}];
    Omega  = Region[{Air, Cond}];
    MagnLinDomain = Region[{Omega}];
    OmegaC = Region[{Cond}];
    OmegaCC = Region[{Air}];
    NonLinOmegaC = Region[{Cond}];
    ArbitraryPoint = Region[ ARBITRARY_POINT ]; // To fix the potential

    // Needed for resolution.pro
    NonLinOmegaC = Region[{Cond}];
}

Function {
    formulation = 2; // FW: formulation = 2
    fill_factor = H_tape / H_turn;

    // foil winding parameters
    dyInd = H_turn*num_tapes;
    dyFoil = H_turn;
    Lx = W_tape;

    DefineConstant [n_vbf = {4, Highlight "LightBlue", Name "Input/5Method/Number of global shape functions (-)"}];

    DefineConstant [try_ASM_before_MUMPS = 0]; // Try ASM before MUMPS (for debugging purposes)
    Flag_try_ASM_before_MUMPS = try_ASM_before_MUMPS;

    tol_rel = 1e-6; // Relative tolerance on nonlinear residual
    tol_abs = 4e-7; // Absolute tolerance on nonlinear residual
}

Include "../common/pancakes_functions.pro";

Constraint {
    { Name phi ;
        Case {
            {Region ArbitraryPoint ; Value 0.0;}
            {Region Sur_Sym; Value 0.0;}
        }
    }
    { Name h ; Type Assign;
        Case {
            {Region Sur_Sym; Value 0.0;}
        }
    }
}

Include "../lib/jac_int.pro";

FunctionSpace {  
  { Name Hregion_u_Foil ; Type Form1P ;
    BasisFunction {
        { Name sr ; NameOfCoef ur ; Function BF_RegionZ ; SubFunction {Function FoilWindingPolynomialBF[]{-1,0.,dyInd,1}; Parameter {0:n_vbf-1:1};} ; Support Region[ Cond ] ; Entity Region[ Cond ] ; }
  }
}

  { Name h_phi_space_2D; Type Form1;
    BasisFunction {
        { Name gradpsin; NameOfCoef phin; Function BF_GradNode;
            Support Omega; Entity NodesOf[OmegaCC]; }
        { Name psie; NameOfCoef he; Function BF_Edge;
            Support Region[{OmegaC}]; Entity EdgesOf[All, Not BndOmegaC]; }
        For i In {1:nbConductors}
            { Name sc; NameOfCoef I~{i}; Function BF_GroupOfEdges;
                Support Omega; Entity GroupsOfEdgesOf[Cut~{i}]; }
        EndFor
    }
    Constraint {
        { NameOfCoef he; EntityType EdgesOf; NameOfConstraint h; }
        { NameOfCoef phin; EntityType NodesOf; NameOfConstraint phi; }
    }
  }
}

Formulation {
    { Name h_2D_fw; Type FemEquation;
        Quantity {
            { Name h; Type Local; NameOfSpace h_phi_space_2D; }
            { Name hp; Type Local; NameOfSpace h_phi_space_2D; }
            { Name ur ; Type Local  ; NameOfSpace Hregion_u_Foil ; }
        }
        Equation {
            Integral { DtDof[ mu[] * Dof{h} , {h} ]; In Omega;  Jacobian Vol; Integration Int; }
            Integral { [ rho_power_built_in[{d h}, mu0*{h}] * Dof{d h} , {d h} ]; In Cond; Integration Int; Jacobian Vol;  }
            Integral { JacNL[ drhodj_timesj_power_built_in[{d h}, mu0*{h}] * Dof{d h} , {d hp} ]; In Cond; Integration Int; Jacobian Vol;  }
            Integral { [ Dof{ur}, {d h} ]; In Cond; Jacobian Vol; Integration Int; }

            Integral { [ Dof{d h}, {ur} ]; In Cond; Jacobian Vol; Integration Int; }
            Integral { [ -I[]/Lx/dyFoil * UnitVectorZ[], {ur} ]; In Cond; Jacobian Vol; Integration Int; }
        }
    }
}

Include "../lib/simple_resolution.pro";

PostProcessing {
    { Name postpro; NameOfFormulation h_2D_fw;
        PostQuantity {
            { Name phi; Value { Term { [ {dInv h} ]; In OmegaCC; Jacobian Vol; } } }
            { Name b; Value { Term { [ mu[] * {h} ]; In Omega; Jacobian Vol; } } }
            { Name h; Value { Term { [ {h} ]; In Omega; Jacobian Vol; } } }
            { Name j; Value{ Term{ [ {d h} ] ; In OmegaC; Jacobian Vol; } } }
            { Name jz_unscaled; Value{ Local{ [ CompZ[{d h}]/fill_factor ] ; In OmegaC; Jacobian Vol; } } }
            { Name abs_j; Value { Term { [ Norm[{d h}] ]; In OmegaC; Jacobian Vol; } } }
            { Name u_Foil ; Value { Term { [ {ur} ] ; In OmegaC ; } } } // this is in V/rad, to be modified by 2*pi if you want to have it in V/turn
            { Name abs_u_Foil; Value { Term { [ Norm[ {ur} ] ]; In OmegaC; Jacobian Vol; } } }
            { Name intj ; Value { Integral { [ {d h} ] ; In Cond ; Jacobian Vol; Integration Int; } } }
            { Name V ; Value { Integral { [ num_tapes / Lx / len_tape / dyInd * {ur} ] ; In Cond ; Jacobian Vol; Integration Int; } } }
            { Name power;
                Value{
                    Integral{ [ mu[] * ({h} - {h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [rho_power_built_in[{d h}, mu0*{h} ] * {d h} * {d h}] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
            { Name dissPower;
                Value{
                    Integral{ [rho_power_built_in[{d h}, mu0*{h} ] * {d h} * {d h}] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name j_jc; Value{ Local{ [ {d h}/jcb[mu0*{h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz_jc; Value{ Local{ [ CompZ[{d h}]/jcb[mu0*{h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name by; Value{ Local{ [ mu[]*normal_vector[]*CompY[{h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name e; Value{ Local{ [ rho_power_built_in[{d h}, mu0*{h}] * {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
        }
    }
}

PostOperation {
    // Extracting energetic quantities
    { Name MagDyn_energy ; LastTimeStepOnly 1 ;
        NameOfPostProcessing postpro;
        Operation{
            Print[ dissPower[NonLinOmegaC], OnGlobal, Format Table, StoreInVariable $indicDissSuper, File > "res/dummy.txt" ];
        }
    }
    { Name MagDyn_energy_full ; LastTimeStepOnly 1 ;
        NameOfPostProcessing postpro;
        Operation{
            Print[ power[Air], OnGlobal, Format TimeTable, StoreInVariable $indicAir, File StrCat[outputDirectory,"/powerAIR.txt"]];
            Print[ dissPower[NonLinOmegaC], OnGlobal, Format TimeTable, StoreInVariable $indicDissSuper, File StrCat[outputDirectory,"/powerNONLINOMEGAC.txt"]];
        }
    }
    { Name detailedPower ; LastTimeStepOnly 1 ;
        NameOfPostProcessing postpro;
        Operation{
            For i In {1:nbConductors}
                Print[ dissPower[Cond~{i}], OnGlobal, Format TimeTable, File > outputPowerCond~{i} ];
            EndFor
        }

    }
    // Runtime output for graph plot
    { Name Info;
        NameOfPostProcessing postpro;
        Operation{
            Print[ time[OmegaC], OnRegion OmegaC, LastTimeStepOnly, Format Table, SendToServer "Output/0Time [s]"] ;
            Print[ dissPower[OmegaC], OnGlobal, LastTimeStepOnly, Format Table, SendToServer "Output/3Joule loss [W]"] ;
        }
    }
    { Name MagDyn;
        NameOfPostProcessing postpro;
        Operation {
            Print[ phi, OnElementsOf OmegaCC , File "res/phi.pos", Name "phi [A]" ];
            Print[ j_jc, OnElementsOf OmegaC , File "res/j_jc.pos", Name "j_jc [-]" ];
            Print[ h, OnElementsOf Omega , File "res/h.pos", Name "h [A/m]" ];
            Print[ b, OnElementsOf Omega , File "res/b.pos", Name "b [T]" ];
            Print[ j, OnElementsOf OmegaC , File "res/j.pos", Name "j [A/m^2]" ];
            Print[ e, OnElementsOf OmegaC , File "res/e.pos", Name "e [V/m]" ];
            Print[ jz_jc, OnElementsOf OmegaC , File "res/jz_jc.pos", Name "jz_jc [A/m^2]" ];
            Print[ by, OnElementsOf OmegaC , File "res/by.pos", Name "by [T]" ];
            Print[ abs_j, OnElementsOf Cond, File "res/j_abs.pos" ];
            Print[ u_Foil, OnElementsOf Cond, File "res/ur.pos" ];
            Print[ abs_u_Foil, OnElementsOf Cond, File "res/ur_abs.pos" ];
            Print[ intj[Omega], OnGlobal, File "res/I_from_j.txt", Format TimeTable, SendToServer "Output/Current on winding" ] ;
            Print[ u_Foil, OnLine {{W_tape/2,1e-9,0}{W_tape/2,dyInd-1e-9,0}}{200}, Format TimeTable, File StrCat[outputDirectory,"/U_line.txt"]] ;
        }
    }
    { Name J_distrib;
        NameOfPostProcessing postpro;
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
