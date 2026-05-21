Function{
    h_xi_fromFile[] = VectorField[xi_to_x[]]; // To get the solution at "xi", we will look at the corresponding "x" in the file

    z[] = Vector[0,0,1];
}

If(formulation == h_formulation + 2)
    Constraint{
        { Name ElectricalCircuit ; Type Network ;
            Case Circuit12 {
              { Region Cut_3 ; Branch {1,2} ; }
              { Region R1 ;   Branch {2,3} ; }
              { Region Cut_6 ; Branch {1,3} ; }
            }
        }
    }
EndIf

FunctionSpace {
    // Function space for visualization (post-processing only)
    { Name h_all_edges; Type Form1;
        BasisFunction {
            { Name psie ; NameOfCoef ae ; Function BF_Edge ;
                Support Omega ; Entity EdgesOf[ All ] ; }
        }
        Constraint {

        }
    }
    // Perpendicular component for the xi_3-independent mode (k=0)
    { Name h_perp_space; Type Form1P;
        BasisFunction {
            { Name sn; NameOfCoef hn; Function BF_PerpendicularEdge;
                Support Omega_h_OmegaC; Entity NodesOf[All, Not BndOmegaC]; }
            { Name rn; NameOfCoef occi; Function BF_RegionZ;
                Support Region[Omega_h_OmegaCC]; Entity Region[Omega_h_OmegaCC]; }
            { Name rn; NameOfCoef occi2; Function BF_GroupOfPerpendicularEdges;
                Support Omega_h_OmegaC; Entity GroupsOfNodesOf[BndOmegaC]; }
        }
        Constraint {
            { NameOfCoef occi ; EntityType Region ; NameOfConstraint h_perp ; }
            { NameOfCoef occi2 ; EntityType GroupsOfNodesOf ; NameOfConstraint h_perp ; }
        }
    }
    // Parallel and perpendicular component (k not 0). There is no cut associated with this space.
    For k In {1:k_max}
        { Name h_space_p~{k}; Type Form1;
            BasisFunction {
                { Name gradpsin; NameOfCoef phin; Function BF_GradNode;
                    Support Omega_h; Entity NodesOf[OmegaCC]; }
                // { Name gradpsin; NameOfCoef phin2; Function BF_GroupOfEdges;
                //    Support Omega_h_OmegaC; Entity GroupsOfEdgesOnNodesOf[BndOmegaC]; } // To treat properly the Omega_CC-Omega_C boundary
                { Name psie; NameOfCoef he; Function BF_Edge;
                    Support Omega_h_OmegaC_AndBnd; Entity EdgesOf[All, Not BndOmegaC]; }
            }
            SubSpace {
                { Name gradpsin ; NameOfBasisFunction gradpsin ; }
                { Name he ; NameOfBasisFunction psie ; }
            }
            Constraint {
                { NameOfCoef phin; EntityType NodesOf; NameOfConstraint phi_p~{k}; }
                // { NameOfCoef phin2; EntityType NodesOf; NameOfConstraint phi_p~{k}; }
                { NameOfCoef he; EntityType EdgesOf; NameOfConstraint h_p~{k}; }
            }
        }
        { Name h_space_m~{k}; Type Form1;
            BasisFunction {
                { Name gradpsin; NameOfCoef phin; Function BF_GradNode;
                    Support Omega_h; Entity NodesOf[OmegaCC]; }
                // { Name gradpsin; NameOfCoef phin2; Function BF_GroupOfEdges;
                //    Support Omega_h_OmegaC; Entity GroupsOfEdgesOnNodesOf[BndOmegaC]; } // To treat properly the Omega_CC-Omega_C boundary
                { Name psie; NameOfCoef he; Function BF_Edge;
                    Support Omega_h_OmegaC_AndBnd; Entity EdgesOf[All, Not BndOmegaC]; }
            }
            SubSpace {
                { Name gradpsin ; NameOfBasisFunction gradpsin ; }
                { Name he ; NameOfBasisFunction psie ; }
            }
            Constraint {
                { NameOfCoef phin; EntityType NodesOf; NameOfConstraint phi_m~{k}; }
                // { NameOfCoef phin2; EntityType NodesOf; NameOfConstraint phi_m~{k}; }
                { NameOfCoef he; EntityType EdgesOf; NameOfConstraint h_m~{k}; }
            }
        }
        /*
        { Name h_space_p~{k}; Type Form1;
            BasisFunction {
                { Name gradpsin; NameOfCoef phin; Function BF_GradNode;
                    Support Omega_h_OmegaCC_AndBnd; Entity NodesOf[OmegaCC]; }
                 { Name gradpsin; NameOfCoef phin2; Function BF_GroupOfEdges;
                    Support Omega_h_OmegaC; Entity GroupsOfEdgesOnNodesOf[BndOmegaC]; } // To treat properly the Omega_CC-Omega_C boundary
                { Name psie; NameOfCoef he; Function BF_Edge;
                    Support Omega_h_OmegaC_AndBnd; Entity EdgesOf[All, Not BndOmegaC]; }
            }
            SubSpace {
                // { Name gradpsin ; NameOfBasisFunction gradpsin ; }
                // { Name he ; NameOfBasisFunction psie ; }
            }
            Constraint {
                { NameOfCoef phin; EntityType NodesOf; NameOfConstraint phi_p~{k}; }
                 { NameOfCoef phin2; EntityType NodesOf; NameOfConstraint phi_p~{k}; }
                { NameOfCoef he; EntityType EdgesOf; NameOfConstraint h_p~{k}; }
            }
        }
        { Name h_space_m~{k}; Type Form1;
            BasisFunction {
                { Name gradpsin; NameOfCoef phin; Function BF_GradNode;
                    Support Omega_h_OmegaCC_AndBnd; Entity NodesOf[OmegaCC]; }
                 { Name gradpsin; NameOfCoef phin2; Function BF_GroupOfEdges;
                    Support Omega_h_OmegaC; Entity GroupsOfEdgesOnNodesOf[BndOmegaC]; } // To treat properly the Omega_CC-Omega_C boundary
                { Name psie; NameOfCoef he; Function BF_Edge;
                    Support Omega_h_OmegaC_AndBnd; Entity EdgesOf[All, Not BndOmegaC]; }
            }
            SubSpace {
                // { Name gradpsin ; NameOfBasisFunction gradpsin ; }
                // { Name he ; NameOfBasisFunction psie ; }
            }
            Constraint {
                { NameOfCoef phin; EntityType NodesOf; NameOfConstraint phi_m~{k}; }
                { NameOfCoef phin2; EntityType NodesOf; NameOfConstraint phi_m~{k}; }
                { NameOfCoef he; EntityType EdgesOf; NameOfConstraint h_m~{k}; }
            }
        }*/
        If(Flag_curlFree == 1)
            { Name h_perp_space_p~{k}; Type Form1P;
                BasisFunction {
                    { Name sn; NameOfCoef hn; Function BF_PerpendicularEdge;
                        Support Omega_h_OmegaC; Entity NodesOf[All, Not BndOmegaC]; }
                    // No constant values in \Occ.
                }
                Constraint {
                    // { NameOfCoef hn; EntityType NodesOf; NameOfConstraint h_perp_p~{k}; }
                }
            }
            { Name h_perp_space_m~{k}; Type Form1P;
                BasisFunction {
                    { Name sn; NameOfCoef hn; Function BF_PerpendicularEdge;
                        Support Omega_h_OmegaC; Entity NodesOf[All, Not BndOmegaC]; }
                    // No constant values in \Occ.
                }
                Constraint {
                    // { NameOfCoef hn; EntityType NodesOf; NameOfConstraint h_perp_m~{k}; }
                }
            }
        Else
            { Name h_perp_space_p~{k}; Type Form1P;
                BasisFunction {
                    { Name sn; NameOfCoef hn; Function BF_PerpendicularEdge;
                        Support Omega_h; Entity NodesOf[All]; }
                    // No constant values in \Occ.
                }
                Constraint {
                    { NameOfCoef hn; EntityType NodesOf; NameOfConstraint h_perp_p~{k}; }
                }
            }
            { Name h_perp_space_m~{k}; Type Form1P;
                BasisFunction {
                    { Name sn; NameOfCoef hn; Function BF_PerpendicularEdge;
                        Support Omega_h; Entity NodesOf[All]; }
                    // No constant values in \Occ.
                }
                Constraint {
                    { NameOfCoef hn; EntityType NodesOf; NameOfConstraint h_perp_m~{k}; }
                }
            }
        EndIf
        { Name lagrangeMult_p~{k}; Type Form0;
            BasisFunction {
                { Name vn; NameOfCoef ln; Function BF_Node;
                    Support Omega_h_OmegaCC_AndBnd; Entity NodesOf[All]; }
            }
            Constraint {
                { NameOfCoef ln; EntityType NodesOf; NameOfConstraint lagrangeMult; }
            }
        }
        { Name lagrangeMult_m~{k}; Type Form0;
            BasisFunction {
                { Name vn; NameOfCoef ln; Function BF_Node;
                    Support Omega_h_OmegaCC_AndBnd; Entity NodesOf[All]; }
            }
            Constraint {
                { NameOfCoef ln; EntityType NodesOf; NameOfConstraint lagrangeMult; }
            }
        }
    EndFor
    // Function space for the circuit domain
    { Name Hregion_Z ; Type Scalar ;
        BasisFunction {
            { Name sr ; NameOfCoef ir ; Function BF_Region ;
            Support Domain_Cir ; Entity Domain_Cir ; }
        }
        GlobalQuantity {
            { Name Iz ; Type AliasOf        ; NameOfCoef ir ; }
            { Name Vz ; Type AssociatedWith ; NameOfCoef ir ; }
        }
        Constraint {
            { NameOfCoef Vz ;
                EntityType Region ; NameOfConstraint Voltage_Cir ; }
            { NameOfCoef Iz ;
                EntityType Region ; NameOfConstraint Current_Cir ; }
        }
    }
}

Formulation {
    { Name HelicalTransfo; Type FemEquation;
        Quantity {
            { Name h; Type Local; NameOfSpace h_all_edges; }
        }
        Equation{
            Galerkin { [ Dof{h} , {h} ];
                In Omega; Integration Int; Jacobian Vol;  }
            Galerkin { [ -h_xi_fromFile[] , {h} ];
                In Omega; Integration Int; Jacobian Vol;  }
        }
    }
    If(k_max==0)
    // h-formulation zeroth-mode
    { Name MagDyn_htot_full; Type FemEquation;
        Quantity {
            { Name h; Type Local; NameOfSpace h_space; }
            { Name I; Type Global; NameOfSpace h_space[I]; }
            { Name V; Type Global; NameOfSpace h_space[V]; }
            { Name hp; Type Local; NameOfSpace h_perp_space; }
        }
        Equation {
            // Time derivative of b (NonMagnDomain)
            Galerkin { [ mu_tilde[] * Dof{h} / $DTime , {h} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            Galerkin { [ mu_tilde[] * Dof{h} / $DTime , {hp} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            Galerkin { [ - mu_tilde[] * ({h}[1]+{hp}[1]) / $DTime , {h} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            Galerkin { [ mu_tilde[] * Dof{hp} / $DTime , {h} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            Galerkin { [ mu_tilde[] * Dof{hp} / $DTime , {hp} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            Galerkin { [ - mu_tilde[] * ({h}[1]+{hp}[1]) / $DTime , {hp} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            // Induced current (NonLinOmegaC)
            Galerkin { [ rho[J[]*({d h}+{d hp}), mu[]*Norm[J[]*({h}+{hp})] ] * T[] * {d h} , {d h} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { [ Jtrans[] * dedj[J[]*({d h}+{d hp}),mu[]*Norm[J[]*({h}+{hp})] ] * J[] * Dof{d h} , {d h} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
            Galerkin { [ - Jtrans[] * dedj[J[]*({d h}+{d hp}),mu[]*Norm[J[]*({h}+{hp})]] * J[] * {d h} , {d h} ];
                In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
            Galerkin { [ rho[J[]*({d h}+{d hp}), mu[]*Norm[J[]*({h}+{hp})] ] * T[] * {d hp} , {d hp} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { [ Jtrans[] * dedj[J[]*({d h}+{d hp}),mu[]*Norm[J[]*({h}+{hp})] ] * J[] * Dof{d hp} , {d hp} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
            Galerkin { [ - Jtrans[] * dedj[J[]*({d h}+{d hp}),mu[]*Norm[J[]*({h}+{hp})]] * J[] * {d hp} , {d hp} ];
                In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
            Galerkin { [ rho[J[]*({d h}+{d hp}), mu[]*Norm[J[]*({h}+{hp})] ] * T[] * {d hp} , {d h} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { [ Jtrans[] * dedj[J[]*({d h}+{d hp}),mu[]*Norm[J[]*({h}+{hp})] ] * J[] * Dof{d hp} , {d h} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
            Galerkin { [ - Jtrans[] * dedj[J[]*({d h}+{d hp}),mu[]*Norm[J[]*({h}+{hp})]] * J[] * {d hp} , {d h} ];
                In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
            Galerkin { [ rho[J[]*({d h}+{d hp}), mu[]*Norm[J[]*({h}+{hp})] ] * T[] * {d h} , {d hp} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { [ Jtrans[] * dedj[J[]*({d h}+{d hp}),mu[]*Norm[J[]*({h}+{hp})] ] * J[] * Dof{d h} , {d hp} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
            Galerkin { [ - Jtrans[] * dedj[J[]*({d h}+{d hp}),mu[]*Norm[J[]*({h}+{hp})]] * J[] * {d h} , {d hp} ];
                In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
            // Induced current (LinOmegaC)
            Galerkin { [ rho_tilde[] * Dof{d h} , {d h} ];
                In LinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { [ rho_tilde[] * Dof{d hp} , {d hp} ];
                In LinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { [ rho_tilde[] * Dof{d hp} , {d h} ];
                In LinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { [ rho_tilde[] * Dof{d h} , {d hp} ];
                In LinOmegaC; Integration Int; Jacobian Vol;  }
            //Galerkin { [ 1 * Dof{d hp} , {d hp} ];
            //    In OmegaCC; Integration Int; Jacobian Vol;  } // To tackle!
            // Induced currents (Global variables)
            GlobalTerm { [ Dof{V} , {I} ] ; In Cuts ; }
        }
    }
    ElseIf(k_max>=1)
    If(Flag_curlFree == 1)
    // h-formulation higher modes
    { Name MagDyn_htot_full; Type FemEquation;
        Quantity {
            For k In {1:k_max}
                { Name h_p~{k}; Type Local; NameOfSpace h_space_p~{k}; }
                { Name gradpsin_p~{k}; Type Local; NameOfSpace h_space_p~{k}[gradpsin]; }
                { Name he_p~{k}; Type Local; NameOfSpace h_space_p~{k}[he]; }
                { Name h_m~{k}; Type Local; NameOfSpace h_space_m~{k}; }
                { Name gradpsin_m~{k}; Type Local; NameOfSpace h_space_m~{k}[gradpsin]; }
                { Name he_m~{k}; Type Local; NameOfSpace h_space_m~{k}[he]; }
                { Name hp_p~{k}; Type Local; NameOfSpace h_perp_space_p~{k}; }
                { Name hp_m~{k}; Type Local; NameOfSpace h_perp_space_m~{k}; }
            EndFor
        }
        Equation {
            For k In {1:k_max}
                // Time derivative of b (NonMagnDomain)
                Galerkin { [ mu_tilde[] * Dof{h_p~{k}} / $DTime , {h_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * Dof{h_p~{k}} / $DTime , {hp_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - z[] * mu_tilde[] * alpha*k * Dof{h_p~{k}} / $DTime , {dInv gradpsin_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }

                Galerkin { [ mu_tilde[] * Dof{hp_p~{k}} / $DTime , {h_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * Dof{hp_p~{k}} / $DTime , {hp_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - z[] * mu_tilde[] * alpha*k * Dof{hp_p~{k}} / $DTime , {dInv gradpsin_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }

                Galerkin { [ - mu_tilde[] * alpha * k * (Dof{dInv gradpsin_m~{k}}*z[]) / $DTime , {h_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - mu_tilde[] * alpha * k * (Dof{dInv gradpsin_m~{k}}*z[]) / $DTime , {hp_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ z[] * mu_tilde[] * alpha*alpha * k*k * (Dof{dInv gradpsin_m~{k}}*z[]) / $DTime , {dInv gradpsin_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }

                Galerkin { [ - mu_tilde[] * ({h_p~{k}}[1]+{hp_p~{k}}[1]-alpha*k*{dInv gradpsin_m~{k}}[1]*z[]) / $DTime , {h_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - mu_tilde[] * ({h_p~{k}}[1]+{hp_p~{k}}[1]-alpha*k*{dInv gradpsin_m~{k}}[1]*z[]) / $DTime , {hp_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ z[] * mu_tilde[] * alpha*k * ({h_p~{k}}[1]+{hp_p~{k}}[1]-alpha*k*{dInv gradpsin_m~{k}}[1]*z[]) / $DTime , {dInv gradpsin_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }

                // Time derivative of b (NonMagnDomain)
                Galerkin { [ mu_tilde[] * Dof{h_m~{k}} / $DTime , {h_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * Dof{h_m~{k}} / $DTime , {hp_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ z[] * mu_tilde[] * alpha*k * Dof{h_m~{k}} / $DTime , {dInv gradpsin_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }

                Galerkin { [ mu_tilde[] * Dof{hp_m~{k}} / $DTime , {h_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * Dof{hp_m~{k}} / $DTime , {hp_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ z[] * mu_tilde[] * alpha*k * Dof{hp_m~{k}} / $DTime , {dInv gradpsin_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }

                Galerkin { [ mu_tilde[] * alpha * k * (Dof{dInv gradpsin_p~{k}}*z[]) / $DTime , {h_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * alpha * k * (Dof{dInv gradpsin_p~{k}}*z[]) / $DTime , {hp_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ z[] * mu_tilde[] * alpha*alpha * k*k * (Dof{dInv gradpsin_p~{k}}*z[]) / $DTime , {dInv gradpsin_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }

                Galerkin { [ - mu_tilde[] * ({h_m~{k}}[1]+{hp_m~{k}}[1]+alpha*k*{dInv gradpsin_p~{k}}[1]*z[]) / $DTime , {h_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - mu_tilde[] * ({h_m~{k}}[1]+{hp_m~{k}}[1]+alpha*k*{dInv gradpsin_p~{k}}[1]*z[]) / $DTime , {hp_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - z[] * mu_tilde[] * alpha*k * ({h_m~{k}}[1]+{hp_m~{k}}[1]+alpha*k*{dInv gradpsin_p~{k}}[1]*z[]) / $DTime , {dInv gradpsin_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }


                // Eddy current (Omega -> LinOmegaC!!)
                Galerkin { [ rho_tilde[] * Dof{d he_p~{k}} , {d he_p~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d hp_p~{k}} , {d hp_p~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d hp_p~{k}} , {d he_p~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d he_p~{k}} , {d hp_p~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ alpha*alpha*k*k * (rho_tilde[] * (z[] /\ Dof{he_p~{k}})) /\ z[] , {he_p~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  } // Double product with z[] is not identity!
                Galerkin { [ alpha*k * rho_tilde[] * (z[] /\ Dof{he_p~{k}}) , {d he_m~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ alpha*k * rho_tilde[] * (z[] /\ Dof{he_p~{k}}) , {d hp_m~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ -alpha*k * (rho_tilde[] * Dof{d he_p~{k}}) /\ z[] , {he_m~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ -alpha*k * (rho_tilde[] * Dof{d hp_p~{k}}) /\ z[] , {he_m~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }

                Galerkin { [ rho_tilde[] * Dof{d he_m~{k}} , {d he_m~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d hp_m~{k}} , {d hp_m~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d hp_m~{k}} , {d he_m~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d he_m~{k}} , {d hp_m~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ alpha*alpha*k*k * (rho_tilde[] * (z[] /\ Dof{he_m~{k}})) /\ z[] , {he_m~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  } // Double product with z[] is not identity!
                Galerkin { [ -alpha*k * rho_tilde[] * (z[] /\ Dof{he_m~{k}}) , {d he_p~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ -alpha*k * rho_tilde[] * (z[] /\ Dof{he_m~{k}}) , {d hp_p~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ +alpha*k * (rho_tilde[] * Dof{d he_m~{k}}) /\ z[] , {he_p~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ +alpha*k * (rho_tilde[] * Dof{d hp_m~{k}}) /\ z[] , {he_p~{k}} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
            EndFor
        }
    }

    Else
    { Name MagDyn_htot_full; Type FemEquation;
        Quantity {
            For k In {1:k_max}
                { Name h_p~{k}; Type Local; NameOfSpace h_space_p~{k}; }
                { Name h_m~{k}; Type Local; NameOfSpace h_space_m~{k}; }
                { Name hp_p~{k}; Type Local; NameOfSpace h_perp_space_p~{k}; }
                { Name hp_m~{k}; Type Local; NameOfSpace h_perp_space_m~{k}; }
                // { Name lm_p~{k}; Type Local; NameOfSpace lagrangeMult_p~{k}; }
                // { Name lm_m~{k}; Type Local; NameOfSpace lagrangeMult_m~{k}; }
            EndFor
        }
        Equation {
            For k In {1:k_max}
                // Time derivative of b (NonMagnDomain)
                Galerkin { [ mu_tilde[] * Dof{h_p~{k}} / $DTime , {h_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * Dof{h_p~{k}} / $DTime , {hp_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - mu_tilde[] * ({h_p~{k}}[1]+{hp_p~{k}}[1]) / $DTime , {h_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * Dof{hp_p~{k}} / $DTime , {h_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * Dof{hp_p~{k}} / $DTime , {hp_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - mu_tilde[] * ({h_p~{k}}[1]+{hp_p~{k}}[1]) / $DTime , {hp_p~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                // Time derivative of b (NonMagnDomain)
                Galerkin { [ mu_tilde[] * Dof{h_m~{k}} / $DTime , {h_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * Dof{h_m~{k}} / $DTime , {hp_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - mu_tilde[] * ({h_m~{k}}[1]+{hp_m~{k}}[1]) / $DTime , {h_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * Dof{hp_m~{k}} / $DTime , {h_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ mu_tilde[] * Dof{hp_m~{k}} / $DTime , {hp_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - mu_tilde[] * ({h_m~{k}}[1]+{hp_m~{k}}[1]) / $DTime , {hp_m~{k}} ];
                    In MagnLinDomain; Integration Int; Jacobian Vol;  }

                // Eddy current (Omega -> LinOmegaC!!)
                Galerkin { [ rho_tilde[] * Dof{d h_p~{k}} , {d h_p~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d hp_p~{k}} , {d hp_p~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d hp_p~{k}} , {d h_p~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d h_p~{k}} , {d hp_p~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ alpha*alpha*k*k * (rho_tilde[] * (z[] /\ Dof{h_p~{k}})) /\ z[] , {h_p~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  } // Double product with z[] is not identity!
                Galerkin { [ alpha*k * rho_tilde[] * (z[] /\ Dof{h_p~{k}}) , {d h_m~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ alpha*k * rho_tilde[] * (z[] /\ Dof{h_p~{k}}) , {d hp_m~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ -alpha*k * (rho_tilde[] * Dof{d h_p~{k}}) /\ z[] , {h_m~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ -alpha*k * (rho_tilde[] * Dof{d hp_p~{k}}) /\ z[] , {h_m~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }

                Galerkin { [ rho_tilde[] * Dof{d h_m~{k}} , {d h_m~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d hp_m~{k}} , {d hp_m~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d hp_m~{k}} , {d h_m~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho_tilde[] * Dof{d h_m~{k}} , {d hp_m~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ alpha*alpha*k*k * (rho_tilde[] * (z[] /\ Dof{h_m~{k}})) /\ z[] , {h_m~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  } // Double product with z[] is not identity!
                Galerkin { [ -alpha*k * rho_tilde[] * (z[] /\ Dof{h_m~{k}}) , {d h_p~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ -alpha*k * rho_tilde[] * (z[] /\ Dof{h_m~{k}}) , {d hp_p~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ +alpha*k * (rho_tilde[] * Dof{d h_m~{k}}) /\ z[] , {h_p~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }
                Galerkin { [ +alpha*k * (rho_tilde[] * Dof{d hp_m~{k}}) /\ z[] , {h_p~{k}} ];
                    In Omega; Integration Int; Jacobian Vol;  }

                // "Gauge" for zero-curl in OmegaCC
                /*Galerkin { [ alpha*k*Dof{dInv h_p~{k}} , {lm_p~{k}} ];
                    In OmegaCC; Integration Int; Jacobian Vol;  }
                Galerkin { [ -Vector[0,0,1] * Dof{hp_m~{k}} , {lm_p~{k}} ];
                    In OmegaCC; Integration Int; Jacobian Vol;  }

                Galerkin { [ -alpha*k*Dof{dInv h_m~{k}} , {lm_m~{k}} ];
                    In OmegaCC; Integration Int; Jacobian Vol;  }
                Galerkin { [ -Vector[0,0,1] * Dof{hp_p~{k}} , {lm_m~{k}} ];
                    In OmegaCC; Integration Int; Jacobian Vol;  }


                Galerkin { [ alpha*k*Dof{lm_p~{k}} , {dInv h_p~{k}} ];
                    In OmegaCC; Integration Int; Jacobian Vol;  }
                Galerkin { [ -Vector[0,0,1] * Dof{lm_p~{k}} , {hp_m~{k}} ];
                    In OmegaCC; Integration Int; Jacobian Vol;  }

                Galerkin { [ -alpha*k*Dof{lm_m~{k}} , {dInv h_m~{k}} ];
                    In OmegaCC; Integration Int; Jacobian Vol;  }
                Galerkin { [ -Vector[0,0,1] * Dof{lm_m~{k}} , {hp_p~{k}} ];
                    In OmegaCC; Integration Int; Jacobian Vol;  } //*/

            EndFor
        }
    }
    EndIf
    EndIf


    // h-formulation with links between currents
    { Name MagDyn_htot_links; Type FemEquation;
        Quantity {
            { Name h; Type Local; NameOfSpace h_space; }
            { Name I; Type Global; NameOfSpace h_space[I]; }
            { Name V; Type Global; NameOfSpace h_space[V]; }
            { Name Vz ; Type Global ; NameOfSpace Hregion_Z [Vz] ; }
            { Name Iz ; Type Global ; NameOfSpace Hregion_Z [Iz] ; }
        }
        Equation {
            // Time derivative of b (NonMagnDomain)
            Galerkin { [ mu[] * Dof{h} / $DTime , {h} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            Galerkin { [ - mu[] * {h}[1] / $DTime , {h} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            // Time derivative of b (MagnAnhyDomain)
            If(Flag_h_NR_Mu)
                Galerkin { [ mu[{h}] * {h} / $DTime , {h} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ dbdh[{h}] * Dof{h} / $DTime , {h}];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - dbdh[{h}] * {h}  / $DTime , {h}];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
            Else
                Galerkin { [ mu[{h}] * Dof{h} / $DTime , {h} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
            EndIf
            Galerkin { [ - mu[{h}[1]] * {h}[1] / $DTime , {h} ];
                In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
            // Induced current (NonLinOmegaC)
            If(Flag_h_NR_Rho)
                Galerkin { [ rho[{d h}, mu[]*Norm[{h}] ] * {d h} , {d h} ];
                    In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ dedj[{d h},mu[]*Norm[{h}] ] * Dof{d h} , {d h} ];
                    In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
                Galerkin { [ - dedj[{d h},mu[]*Norm[{h}]] * {d h} , {d h} ];
                    In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
            Else
                Galerkin { [ rho[{d h}, mu[]*Norm[{h}]] * Dof{d h} , {d h} ];
                    In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            EndIf
            // Induced current (LinOmegaC)
            Galerkin { [ rho[] * Dof{d h} , {d h} ];
                In LinOmegaC; Integration Int; Jacobian Vol;  }
            // Induced currents (Global variables)
            GlobalTerm { [ Dof{V} , {I} ] ; In Cuts ; }
            // Example of surface term for natural condition (be careful!)
            //If(SourceType == 3)
            //    Galerkin { [ - (bs_bnd[] - bs_bnd_prev[])/$DTime * Normal[] , {dInv h} ];
            //        In Gamma_e; Integration Int; Jacobian Sur;  }
            //EndIf

            GlobalTerm { [ Dof{Vz}                , {Iz} ] ; In R1 ; }
            GlobalTerm { [ Resistance[] * Dof{Iz} , {Iz} ] ; In R1 ; }

            GlobalEquation {
                Type Network ; NameOfConstraint ElectricalCircuit ;
                { Node {I};  Loop {V};  Equation {V};  In Cuts ; }
                { Node {Iz}; Loop {Vz}; Equation {Vz}; In Domain_Cir ; }
          	}
        }
    }
}

Resolution {
    { Name HelicalTransfo;
        System {
            {Name A; NameOfFormulation HelicalTransfo;}
        }
        Operation {
            GmshRead["../filaments/res/h_xi.pos"]; // Should be saved without mesh format! (and only last time step)
            Generate[A]; Solve[A]; SaveSolution[A];
        }
    }
}

PostProcessing {
    { Name HelicalTransfo; NameOfFormulation HelicalTransfo;
        Quantity {
            { Name h_transformed; Value{ Local{ [ {h} ] ;
                In Omega; Jacobian Vol; } } }
        }
    }
    If(k_max==0)
    // h-formulation, total field
    { Name MagDyn_htot_full; NameOfFormulation MagDyn_htot_full;
        Quantity {
            { Name phi; Value{ Local{ [ {dInv h} ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name h; Value{ Local{ [ Jinvtrans[]*({h} + {hp}) ] ;
                In Omega; Jacobian Vol; } } }
            { Name h_12_xi; Value{ Local{ [ ({h}) ] ;
                In Omega; Jacobian Vol; } } }
            { Name h_3_xi; Value{ Local{ [ ({hp}) ] ;
                In Omega; Jacobian Vol; } } }
            { Name h_12_x; Value{ Local{ [ Jinvtrans[]*({h}) ] ;
                In Omega; Jacobian Vol; } } }
            { Name h_3_x; Value{ Local{ [ Jinvtrans[]*({hp}) ] ;
                In Omega; Jacobian Vol; } } }
            { Name h_xi; Value{ Local{ [ ({h} + {hp}) ] ;
                In Omega; Jacobian Vol; } } }
            { Name b; Value {
                Term { [ mu[] * Jinvtrans[]*( {h} + {hp} ) ] ; In MagnLinDomain; Jacobian Vol; }
                //Term { [ mu[{h}] * {h} ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name bz_vec; Value {
                Term { [ CompZ[mu[] * Jinvtrans[]*({h} + {hp})]*Vector[0,0,1] ] ; In MagnLinDomain; Jacobian Vol; }
                //Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name bz; Value {
                Term { [ CompZ[mu[] * Jinvtrans[]*({h} + {hp})] ] ; In MagnLinDomain; Jacobian Vol; }
                //Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name bplane; Value {
                Term { [ CompX[mu[] * Jinvtrans[]*({h} + {hp})]*Vector[1,0,0]
                    + CompY[mu[] * Jinvtrans[]*({h} + {hp})]*Vector[0,1,0] ] ; In MagnLinDomain; Jacobian Vol; }
                //Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name mur; Value{ Local{ [ mu[{h}]/mu0 ] ;
                In MagnAnhyDomain; Jacobian Vol; } } }
            { Name j; Value{ Local{ [ J[]*({d h} + {d hp}) ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name j_xi; Value{ Local{ [ ({d h} + {d hp}) ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name e; Value{ Local{ [ rho[J[]*({d h} + {d hp}), mu0*Norm[Jinvtrans[]*({h}+{hp})]] * J[]*({d h} + {d hp}) ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz; Value{ Local{ [ CompZ[J[]*({d h} + {d hp})] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jplane; Value {
                Term { [ CompX[J[]*({d h} + {d hp})]*Vector[1,0,0]
                    + CompY[J[]*({d h} + {d hp})]*Vector[0,1,0] ] ; In OmegaC; Jacobian Vol; }
                //Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name jx; Value{ Local{ [ CompX[J[]*({d h} + {d hp})] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jy; Value{ Local{ [ CompY[J[]*({d h} + {d hp})] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name norm_j; Value{ Local{ [ Norm[J[]*({d h} + {d hp})] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jouleLosses; Value{ Local{ [ rho[J[]*({d h} + {d hp}), mu0*Norm[Jinvtrans[]*({h}+{hp})]]*({d h} + {d hp})*T[]*({d h} + {d hp}) ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name area; Value{ Integral{ [ CompZ[J[]*({d h} + {d hp})] ] ;
                In OmegaC; Integration Int; Jacobian Vol; } } }
            /*If(Axisymmetry == 1)
                { Name m_avg; Value{ Integral{ [ 2*Pi * 0.5 * XYZ[] /\ {d h} / (Pi*SurfaceArea[]*W/2) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } } // Jacobian is in "Vol"
                { Name m_avg_y_tesla; Value{ Integral{ [ mu0*2*Pi * 0.5 * Vector[0,1,0] * (XYZ[] /\ {d h}) / (Pi*SurfaceArea[]*W/2) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
            ElseIf(Dim == 1)
                // TBC...
            ElseIf(Dim == 2)
                // Not axisym, so surface integral to give (total) magnetization per unit length.
                // Here, the average is computed. ATTENTION: Factor 2 (to account for magn. at the ends) is not introduced
                { Name m_avg; Value{ Integral{ [ 0.5 * XYZ[] /\ {d h} / (SurfaceArea[]) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
                { Name m_avg_y_tesla; Value{ Integral{ [ mu0 * 0.5 * Vector[0,1,0] * (XYZ[] /\ {d h}) / (SurfaceArea[]) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
                { Name m_avg_x_tesla; Value{ Integral{ [ mu0 * 0.5 * Vector[1,0,0] * (XYZ[] /\ {d h}) / (SurfaceArea[]) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
            ElseIf(Dim == 3)
                { Name m_avg; Value{ Integral{ [ 0.5 * XYZ[] /\ {d h} / GetVolume[] ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
            EndIf*/
            { Name hsVal; Value{ Term { [ hsVal[] ]; In Omega; } } }
            { Name bsVal; Value{ Term { [ mu0*hsVal[] ]; In Omega; } } }
            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }
            { Name power; // (h+h[1])/2 instead of h -> to avoid a constant sign error accumulation
                Value{
                    //Integral{ [ (mu[{h}]*{h} - mu[{h}[1]]*{h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                    //    In MagnAnhyDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [ mu[] * ({h}+{hp}-{h}[1]-{hp}[1]) / $DTime * Tinv[] *({h}+{hp}+{h}[1]+{hp}[1])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [rho[J[]*({d h} + {d hp}), mu0*Norm[Jinvtrans[]*({h}+{hp})]]*({d h} + {d hp})*T[]*({d h} + {d hp})] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
            { Name V; Value { Term{ [ {V} ] ; In Cuts; } } }
            { Name I; Value { Term{ [ {I} ] ; In Cuts; } } }
            { Name dissPowerGlobal;
                Value { Term{ [ {V}*{I} ] ; In Cuts; } } }
            { Name dissPower;
                Value{
                    Integral{ [rho[J[]*({d h} + {d hp}), mu0*Norm[Jinvtrans[]*({h}+{hp})]]*({d h} + {d hp})*T[]*({d h} + {d hp})] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
        }
    }
    EndIf
    If(k_max>=1)
    // h-formulation, total field
    { Name MagDyn_htot_full; NameOfFormulation MagDyn_htot_full;
        Quantity {
            If(Flag_curlFree == 0)
                { Name phi; Value{ Local{ [ {dInv h_m_1} ] ;
                    In Omega; Jacobian Vol; } } }
                { Name h; Value{ Local{ [ Sqrt[2] * Jinvtrans[]*({h_m_1} + {hp_m_1}) ] ; //
                    In Omega; Jacobian Vol; } } }
                { Name h_sin; Value{ Local{ [ Sqrt[2] * Jinvtrans[]*({h_p_1} + {hp_p_1}) ] ;
                    In Omega; Jacobian Vol; } } }
                { Name j; Value{ Local{ [ Sqrt[2]*J[]*({d h_m_1} + {d hp_m_1} + alpha * z[] /\ {h_p_1} )];// - alpha * z[] /\ {gradpsin_p_1}) ] ;
                    In Omega; Jacobian Vol; } } } // {h_p_1} -> {he_p_1}
                { Name j_xi; Value{ Local{ [ Sqrt[2]*({d h_m_1} + {d hp_m_1} + alpha * z[] /\ {h_p_1}) ] ;
                    In OmegaC; Jacobian Vol; } } }
            Else
                { Name phi; Value{ Local{ [ {dInv h_m_1} ] ;
                    In Omega; Jacobian Vol; } } }
                { Name h; Value{ Local{ [ Sqrt[2] * Jinvtrans[]*({h_m_1} + {hp_m_1} + alpha*{dInv gradpsin_p_1}*z[]) ] ; //
                    In Omega; Jacobian Vol; } } }
                { Name h_sin; Value{ Local{ [ Sqrt[2] * Jinvtrans[]*({h_p_1} + {hp_p_1} - alpha*{dInv gradpsin_m_1}*z[]) ] ;
                    In Omega; Jacobian Vol; } } }
                { Name j; Value{ Local{ [ Sqrt[2]*J[]*({d h_m_1} + {d hp_m_1} + alpha * z[] /\ {he_p_1} )];// - alpha * z[] /\ {gradpsin_p_1}) ] ;
                    In Omega; Jacobian Vol; } } } // {h_p_1} -> {he_p_1}
                { Name j_xi; Value{ Local{ [ Sqrt[2]*({d h_m_1} + {d hp_m_1} + alpha * z[] /\ {h_p_1} - alpha * z[] /\ {gradpsin_p_1}) ] ;
                    In OmegaC; Jacobian Vol; } } }
            EndIf

            { Name phi_12_p_xi; Value{ Local{ [ ({dInv h_p_1}) ] ;
                In Omega; Jacobian Vol; } } }
            { Name phi_12_m_xi; Value{ Local{ [ ({dInv h_m_1}) ] ;
                In Omega; Jacobian Vol; } } }
            { Name h_3_p_xi; Value{ Local{ [ ({hp_p_1}) ] ;
                In Omega; Jacobian Vol; } } }
            { Name h_3_m_xi; Value{ Local{ [ ({hp_m_1}) ] ;
                In Omega; Jacobian Vol; } } }
            /*{ Name h_12_x; Value{ Local{ [ Jinvtrans[]*({h}) ] ;
                In Omega; Jacobian Vol; } } }
            { Name h_3_x; Value{ Local{ [ Jinvtrans[]*({hp}) ] ;
                In Omega; Jacobian Vol; } } }*/
            /*{ Name h_xi; Value{ Local{ [ ({h_m_1} + {hp_m_1} + alpha*{dInv gradpsin_p_1}*z[]) ] ;
                In Omega; Jacobian Vol; } } }
            { Name hp_xi; Value{ Local{ [ ({hp_m_1} + alpha*{dInv gradpsin_p_1}*z[]) ] ;
                In Omega; Jacobian Vol; } } }
            { Name he_xi; Value{ Local{ [ {he_p_1} ] ;
                In Omega; Jacobian Vol; } } }*/
            { Name b; Value {
                Term { [ mu[] * Sqrt[2] * Jinvtrans[]*({h_m_1} + {hp_m_1} + alpha*{dInv gradpsin_p_1}*z[]) ] ; In MagnLinDomain; Jacobian Vol; }
                }
            }
            { Name b_sin; Value {
                Term { [ mu[] * Sqrt[2] * Jinvtrans[]*({h_p_1} + {hp_p_1} - alpha*{dInv gradpsin_m_1}*z[]) ] ; In MagnLinDomain; Jacobian Vol; }
                }
            }
            /*{ Name bz_vec; Value {
                Term { [ CompZ[mu[] * Jinvtrans[]*({h} + {hp})]*Vector[0,0,1] ] ; In MagnLinDomain; Jacobian Vol; }
                //Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }*/
            { Name bz; Value {
                Term { [ CompZ[mu[] * Sqrt[2] * Jinvtrans[]*({h_m_1} + {hp_m_1} + alpha*{dInv gradpsin_p_1}*z[]) ]] ; In MagnLinDomain; Jacobian Vol; }
                //Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name b_sinz; Value {
                Term { [ CompZ[mu[] * Sqrt[2] * Jinvtrans[]*({h_p_1} + {hp_p_1} - alpha*{dInv gradpsin_m_1}*z[]) ]] ; In MagnLinDomain; Jacobian Vol; }
                //Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            /*{ Name bplane; Value {
                Term { [ CompX[mu[] * Jinvtrans[]*({h} + {hp})]*Vector[1,0,0]
                    + CompY[mu[] * Jinvtrans[]*({h} + {hp})]*Vector[0,1,0] ] ; In MagnLinDomain; Jacobian Vol; }
                //Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }*/
            /*{ Name mur; Value{ Local{ [ mu[{h}]/mu0 ] ;
                In MagnAnhyDomain; Jacobian Vol; } } }*/
            /*{ Name e; Value{ Local{ [ rho[J[]*({d h} + {d hp}), mu0*Norm[Jinvtrans[]*({h}+{hp})]] * J[]*({d h} + {d hp}) ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz; Value{ Local{ [ CompZ[J[]*({d h} + {d hp})] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jx; Value{ Local{ [ CompX[J[]*({d h} + {d hp})] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jy; Value{ Local{ [ CompY[J[]*({d h} + {d hp})] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name norm_j; Value{ Local{ [ Norm[J[]*({d h} + {d hp})] ] ;
                In OmegaC; Jacobian Vol; } } }*/
            // { Name area; Value{ Integral{ [ CompZ[J[]*({d h} + {d hp})] ] ;
            //    In OmegaC; Integration Int; Jacobian Vol; } } }
            { Name hsVal; Value{ Term { [ hsVal[] ]; In Omega; } } }
            { Name bsVal; Value{ Term { [ mu0*hsVal[] ]; In Omega; } } }
            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }
            { Name power; // (h+h[1])/2 instead of h -> to avoid a constant sign error accumulation
                Value{
                    //Integral{ [ (mu[{h}]*{h} - mu[{h}[1]]*{h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                    //    In MagnAnhyDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [ mu[] * ({h_m_1}+{hp_m_1}+alpha*{dInv gradpsin_p_1}*z[]-{h_m_1}[1]-{hp_m_1}[1]-alpha*{dInv gradpsin_p_1}[1]*z[]) / $DTime * Tinv[] *({h_m_1}+{hp_m_1}+alpha*{dInv gradpsin_p_1}*z[]+{h_m_1}[1]+{hp_m_1}[1]-alpha*{dInv gradpsin_p_1}[1]*z[])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; } // No sqrt(2) because normed modes integrated over one pitch
                    Integral{ [rho[J[]*({d h_m_1}+{d hp_m_1}+alpha*z[]/\{he_p_1}), mu0*Norm[Jinvtrans[]*({h_m_1}+{hp_m_1})]]*({d h_m_1}+{d hp_m_1}+alpha*z[]/\{he_p_1})*T[]*({d h_m_1}+{d hp_m_1}+alpha*z[]/\{he_p_1})] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                    Integral{ [ mu[] * ({h_p_1}+{hp_p_1}-alpha*{dInv gradpsin_m_1}*z[]-{h_p_1}[1]-{hp_p_1}[1]+alpha*{dInv gradpsin_m_1}[1]*z[]) / $DTime * Tinv[] *({h_p_1}+{hp_p_1}-alpha*{dInv gradpsin_m_1}*z[]+{h_p_1}[1]+{hp_p_1}[1]+alpha*{dInv gradpsin_m_1}[1]*z[])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [rho[J[]*({d h_p_1}+{d hp_p_1}-alpha*z[]/\{he_m_1}), mu0*Norm[Jinvtrans[]*({h_p_1}+{hp_p_1})]]*({d h_p_1}+{d hp_p_1}-alpha*z[]/\{he_m_1})*T[]*({d h_p_1}+{d hp_p_1}-alpha*z[]/\{he_m_1})] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
            { Name V; Value { Term{ [ 0 ] ; In Cuts; } } }
            { Name I; Value { Term{ [ 0 ] ; In Cuts; } } }
            { Name dissPowerGlobal;
                Value { Term{ [ hsVal[] ] ; In Cuts; } } }
            { Name dissPower;
                Value{
                    Integral{ [rho[J[]*({d h_m_1}+{d hp_m_1}+alpha*z[]/\{he_p_1}), mu0*Norm[Jinvtrans[]*({h_m_1}+{hp_m_1})]]*({d h_m_1}+{d hp_m_1}+alpha*z[]/\{he_p_1})*T[]*({d h_m_1}+{d hp_m_1}+alpha*z[]/\{he_p_1})] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                    Integral{ [rho[J[]*({d h_p_1}+{d hp_p_1}-alpha*z[]/\{he_m_1}), mu0*Norm[Jinvtrans[]*({h_p_1}+{hp_p_1})]]*({d h_p_1}+{d hp_p_1}-alpha*z[]/\{he_m_1})*T[]*({d h_p_1}+{d hp_p_1}-alpha*z[]/\{he_m_1})] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
        }
    }
    EndIf
    // h-formulation, total field
    { Name MagDyn_htot_links; NameOfFormulation MagDyn_htot_links;
        Quantity {
            { Name phi; Value{ Local{ [ {dInv h} ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name h; Value{ Local{ [ {h} ] ;
                In Omega; Jacobian Vol; } } }
            { Name b; Value {
                Term { [ mu[] * {h} ] ; In MagnLinDomain; Jacobian Vol; }
                Term { [ mu[{h}] * {h} ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name bz_vec; Value {
                Term { [ CompZ[mu[] * {h}]*Vector[0,0,1] ] ; In MagnLinDomain; Jacobian Vol; }
                Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name bz; Value {
                Term { [ CompZ[mu[]*({h})] ] ; In MagnLinDomain; Jacobian Vol; }
                //Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name bplane; Value {
                Term { [ CompX[mu[]*({h})]*Vector[1,0,0]
                    + CompY[mu[]*({h})]*Vector[0,1,0] ] ; In MagnLinDomain; Jacobian Vol; }
                //Term { [ CompZ[mu[{h}] * {h}]*Vector[0,0,1] ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name mur; Value{ Local{ [ mu[{h}]/mu0 ] ;
                In MagnAnhyDomain; Jacobian Vol; } } }
            { Name j; Value{ Local{ [ {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name js; Value{ Local{ [ {d h} ] ;
                In OmegaC_stranded; Jacobian Vol; } } }
            { Name e; Value{ Local{ [ rho[{d h}, mu0*Norm[{h}]] * {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz; Value{ Local{ [ CompZ[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jx; Value{ Local{ [ CompX[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jy; Value{ Local{ [ CompY[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name norm_j; Value{ Local{ [ Norm[{d h}] ] ;
                In OmegaC; Jacobian Vol; } } }
            If(Axisymmetry == 1)
                { Name m_avg; Value{ Integral{ [ 2*Pi * 0.5 * XYZ[] /\ {d h} / (Pi*SurfaceArea[]*W/2) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } } // Jacobian is in "Vol"
                { Name m_avg_y_tesla; Value{ Integral{ [ mu0*2*Pi * 0.5 * Vector[0,1,0] * (XYZ[] /\ {d h}) / (Pi*SurfaceArea[]*W/2) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
            ElseIf(Dim == 1)
                // TBC...
            ElseIf(Dim == 2)
                // Not axisym, so surface integral to give (total) magnetization per unit length.
                // Here, the average is computed. ATTENTION: Factor 2 (to account for magn. at the ends) is not introduced
                { Name m_avg; Value{ Integral{ [ 0.5 * XYZ[] /\ {d h} / (SurfaceArea[]) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
                { Name m_avg_y_tesla; Value{ Integral{ [ mu0 * 0.5 * Vector[0,1,0] * (XYZ[] /\ {d h}) / (SurfaceArea[]) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
                { Name m_avg_x_tesla; Value{ Integral{ [ mu0 * 0.5 * Vector[1,0,0] * (XYZ[] /\ {d h}) / (SurfaceArea[]) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
            ElseIf(Dim == 3)
                { Name m_avg; Value{ Integral{ [ 0.5 * XYZ[] /\ {d h} / GetVolume[] ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
            EndIf
            { Name hsVal; Value{ Term { [ hsVal[] ]; In Omega; } } }
            { Name bsVal; Value{ Term { [ mu0*hsVal[] ]; In Omega; } } }
            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }
            If(Flag_MB == 1)
                { Name rotor_angle; Value{ Term { [ 180/Pi*omega*$Time ]; In Omega; } } }
            EndIf
            { Name power; // (h+h[1])/2 instead of h -> to avoid a constant sign error accumulation
                Value{
                    Integral{ [ (mu[{h}]*{h} - mu[{h}[1]]*{h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                        In MagnAnhyDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [ mu[] * ({h} - {h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [rho[{d h}, mu0*Norm[{h}] ]*{d h}*{d h}] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
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
