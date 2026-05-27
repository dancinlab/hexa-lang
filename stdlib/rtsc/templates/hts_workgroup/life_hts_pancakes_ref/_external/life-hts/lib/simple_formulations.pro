// This file only contains a simplified version of the h-phi formulation.
// See file "lib/formulations.pro" for the complete version of other formulations.

// ----------------------------------------------------------------------------
// --------------------------- FUNCTION SPACE ---------------------------------
// ----------------------------------------------------------------------------
FunctionSpace {
    // Function space for magnetic field h in h-conform formulation
    //  h = sum phi_n * grad(psi_n)     (nodes in Omega_CC with boundary)
    //      + sum h_e * psi_e           (edges in Omega_C)
    //      + sum I_i * c_i             (cuts, global basis functions for net current intensity)
    { Name h_space; Type Form1;
        BasisFunction {
            { Name gradpsin; NameOfCoef phin; Function BF_GradNode;
                Support Region[{Omega,GammaAll}]; Entity NodesOf[{OmegaCC, BndOmegaC}]; }
            { Name psie; NameOfCoef he; Function BF_Edge;
                Support Region[{OmegaC, BndOmegaC}]; Entity EdgesOf[All, Not BndOmegaC]; }
            { Name sc; NameOfCoef Ii; Function BF_GroupOfEdges;
                Support Region[{Omega,GammaAll}]; Entity GroupsOfEdgesOf[Cuts]; }
        }
        GlobalQuantity {
            { Name I ; Type AliasOf        ; NameOfCoef Ii ; }
            { Name V ; Type AssociatedWith ; NameOfCoef Ii ; }
        }
        Constraint {
            { NameOfCoef phin; EntityType NodesOf; NameOfConstraint phi; }
            { NameOfCoef he; EntityType EdgesOf; NameOfConstraint h; }
            { NameOfCoef Ii ;
                EntityType GroupsOfEdgesOf ; NameOfConstraint Current ; }
            { NameOfCoef V ;
                EntityType GroupsOfNodesOf ; NameOfConstraint Voltage ; }
        }
    }
}

// ----------------------------------------------------------------------------
// --------------------------- FORMULATION ------------------------------------
// ----------------------------------------------------------------------------

Formulation {
    // h-formulation
    { Name MagDyn_htot; Type FemEquation;
        Quantity {
            { Name h; Type Local; NameOfSpace h_space; }
            { Name hp; Type Local; NameOfSpace h_space; }
            { Name I; Type Global; NameOfSpace h_space[I]; }
            { Name V; Type Global; NameOfSpace h_space[V]; }
        }
        Equation {
            // Time derivative of magnetic flux density
            Galerkin { DtDof[ mu[] * Dof{h}, {h} ];
                In Omega; Integration Int_1; Jacobian Vol;  }
            // Induced Currents (linear conductors)
            Galerkin { [ rho[] * Dof{d h} , {d h} ];
                In LinOmegaC; Integration Int_0; Jacobian Vol;  }
            // Induced Currents (non-linear conductors)
            Galerkin { [ rho_power_built_in[{d h}, mu0*Norm[{h}]] * Dof{d h} , {d h} ];
                In NonLinOmegaC; Integration Int_0; Jacobian Vol;  }
            Galerkin { JacNL[ drhodj_timesj_power_built_in[{d h}, mu0*Norm[{h}]] * Dof{d h} , {d h} ];
                In OmegaC; Integration Int_0; Jacobian Vol;  }
            // Induced currents (Global variables)
            If(Flag_compute_voltage_h_phi)
                GlobalTerm { [ Dof{V} , {I} ] ; In Cuts ; }
            EndIf
        }
    }
}

// ----------------------------------------------------------------------------
// --------------------------- POST-PROCESSING --------------------------------
// ----------------------------------------------------------------------------
PostProcessing {
    // h-formulation
    { Name MagDyn_htot; NameOfFormulation MagDyn_htot;
        Quantity {
            { Name phi; Value{ Local{ [ {dInv h} ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name h; Value{ Local{ [ {h} ] ;
                In Omega; Jacobian Vol; } } }
            { Name b; Value{ Local{ [ mu[] * {h} ] ; 
                In Omega; Jacobian Vol; } } }
            { Name j; Value{ Local{ [ {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name e; Value{ Local{ [ rho[{d h}, mu0*Norm[{h}]] * {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jouleLosses; Value{ Local{ [ rho[{d h}, mu0*Norm[{h}]] * {d h} * {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz; Value{ Local{ [ CompZ[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jx; Value{ Local{ [ CompX[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jy; Value{ Local{ [ CompY[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name norm_j; Value{ Local{ [ Norm[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name V; Value { Term{ [ {V} ] ; In Cuts; } } }
            { Name I; Value { Term{ [ {I} ] ; In Cuts; } } }
            { Name dissPowerGlobal;
                Value { Term{ [ {V}*{I} ] ; In Cuts; } } }
            { Name dissPower;
                Value{
                    Integral{ [rho[{d h}, mu0*Norm[{h}] ]*{d h}*{d h}] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
        }
    }
}
