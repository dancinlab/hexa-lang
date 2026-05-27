// ----------------------------------------------------------------------------
// --------------------------- FUNCTION SPACE ---------------------------------
// ----------------------------------------------------------------------------
// Gauge condition for the vector potential
Group {
    Surf_a_noGauge = Region [ {Gamma_e, BndOmegaC} ] ;
}
Constraint {
    { Name GaugeCondition ; Type Assign ;
        Case {
            If(formulation == ta_formulation)
                // Gauge in the whole domain
                {Region Omega ; SubRegion Surf_a_noGauge; Value 0.; }
            Else
                // Zero on edges of a tree in Omega_CC, containing a complete tree on Surf_a_noGauge
                {Region Omega_a_OmegaCC ; SubRegion Surf_a_noGauge; Value 0.; }
            EndIf
        }
    }
}
// Function spaces for the spatial discretization
FunctionSpace {
    // Function space for magnetic field h in h-conform formulation
    //  h = sum phi_n * grad(psi_n)     (nodes in Omega_CC with boundary)
    //      + sum h_e * psi_e           (edges in Omega_C)
    //      + sum I_i * c_i             (cuts, global basis functions for net current intensity)
    //      + sum I_s * h_s0            (global source field for stranded conductors)
    { Name h_space; Type Form1;
        BasisFunction {
            /*{ Name gradpsin; NameOfCoef phin; Function BF_GradNode;
                Support Omega_h_AndBnd; Entity NodesOf[OmegaCC]; } // for single term */
            { Name gradpsin; NameOfCoef phin; Function BF_GradNode;
                Support Omega_h_OmegaCC_AndBnd; Entity NodesOf[OmegaCC]; } // Extend support to boundary for surface integration
            { Name gradpsin; NameOfCoef phin2; Function BF_GroupOfEdges;
                Support Omega_h_OmegaC; Entity GroupsOfEdgesOnNodesOf[BndOmegaC]; } // To treat properly the Omega_CC-Omega_C boundary
            If(a_enrichment == 0)
                { Name gradpsin2; NameOfCoef phi2nd; Function BF_GradNode_2E; // For coupled formulation, if order of a is chosen not to be increased
                    Support Omega_h_AndBnd; Entity EdgesOf[BndOmega_ha]; }
            EndIf
            { Name psie; NameOfCoef he; Function BF_Edge;
                Support Omega_h_OmegaC_AndBnd; Entity EdgesOf[All, Not BndOmegaC]; }

            // { Name gradpsin2; NameOfCoef phi2nd2; Function BF_GroupOfEdges_2E;
            //     Support Omega_h_OmegaC; Entity GroupsOfEdgesOnNodesOf[BndOmega_ha]; }

            /*{ Name gradpsin3; NameOfCoef phin_3; Function BF_GradNode_2E;
                Support Omega_h_OmegaCC_AndBnd; Entity EdgesOf[OmegaCC]; } // Extend support to boundary for surface integration
            { Name gradpsin3; NameOfCoef phin2_3; Function BF_GroupOfEdges_2E;
                Support Omega_h_OmegaC; Entity GroupsOfEdgesOnNodesOf[BndOmegaC]; }*/

            /*{ Name psie3a ; NameOfCoef ae3a ; Function BF_Edge_3F_a ;
                Support Omega_h_OmegaC ; Entity FacetsOf[ All, Not BndOmegaC ] ; }
            { Name psie3b ; NameOfCoef ae3b ; Function BF_Edge_3F_b ;
                Support Omega_h_OmegaC ; Entity FacetsOf[ All, Not BndOmegaC ] ; }*/

            If(Flag_cohomology == 0)
                { Name ci; NameOfCoef Ii; Function BF_GradGroupOfNodes;
                    Support ElementsOf[Omega_h_OmegaCC, OnPositiveSideOf Cuts];
                    Entity GroupsOfNodesOf[Cuts]; }
                { Name ci; NameOfCoef Ii2; Function BF_GroupOfEdges;
                    Support Omega_h_OmegaC_AndBnd;
                    Entity GroupsOfEdgesOf[Cuts, InSupport TransitionLayerAndBndOmegaC] ; } // To treat properly the Cut-Omega_C junction
            Else
                { Name sc; NameOfCoef Ii; Function BF_GroupOfEdges;
                    Support Omega_h_AndBnd; Entity GroupsOfEdgesOf[Cuts]; }
            EndIf
            If(Flag_hs == 1)
                { Name sb ; NameOfCoef Is ;  // Global Basis Function
                    Function BF_Global {
                        Quantity hs ;
                        Formulation js_to_hs {Nb_source_domain};
                        Group OmegaC_stranded ; Resolution js_to_hs {Nb_source_domain};
                    } ;
                    Support Omega_h_AndBnd ; Entity Global [OmegaC_stranded] ;
                }
            EndIf
        }
        SubSpace {
            If(Flag_hs == 1)
                { Name hs ; NameOfBasisFunction sb ; }
            EndIf
        }
        GlobalQuantity {
            { Name I ; Type AliasOf        ; NameOfCoef Ii ; }
            { Name V ; Type AssociatedWith ; NameOfCoef Ii ; }
            If(Flag_hs == 1)
                { Name Is ; Type AliasOf        ; NameOfCoef Is ; }
                { Name Vs ; Type AssociatedWith ; NameOfCoef Is ; }
            EndIf
        }
        Constraint {
            { NameOfCoef phin; EntityType NodesOf; NameOfConstraint phi; }
            { NameOfCoef phin2; EntityType NodesOf; NameOfConstraint phi; }
            { NameOfCoef he; EntityType EdgesOf; NameOfConstraint h; }
            { NameOfCoef Ii ;
                EntityType GroupsOfEdgesOf ; NameOfConstraint Current ; }
            If(Flag_cohomology == 0)
                { NameOfCoef Ii2 ;
                    EntityType GroupsOfNodesOf ; NameOfConstraint Current ; }
            EndIf
            { NameOfCoef V ;
                EntityType GroupsOfNodesOf ; NameOfConstraint Voltage ; }
            If(Flag_hs == 1)
                { NameOfCoef Is ;
                    EntityType Region ; NameOfConstraint Current_s ; }
                { NameOfCoef Vs ;
                    EntityType Region ; NameOfConstraint Voltage_s ; }
            EndIf
        }
    }
    /*{ Name b_or_h_space ; Type Vector;
        BasisFunction {
            { Name svx ; NameOfCoef avx ; Function BF_VolumeX ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            { Name svy ; NameOfCoef avy ; Function BF_VolumeY ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
             { Name svz ; NameOfCoef avz ; Function BF_VolumeZ ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            // Different tests with possibly home-made shape functions
            /*{ Name sex ; NameOfCoef aex ; Function BF_NodeX ;
                Support MagnAnhyDomain ; Entity NodesOf[ All ] ; }
            { Name sey ; NameOfCoef aey ; Function BF_NodeY ;
                Support MagnAnhyDomain ; Entity NodesOf[ All ] ; }*/
            // { Name sez ; NameOfCoef aez ; Function BF_NodeZ ;
            //    Support MagnAnhyDomain ; Entity NodesOf[ All ] ; }
            /*{ Name svx ; NameOfCoef avx ; Function BF_Volume_1Ea ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            { Name svy ; NameOfCoef avy ; Function BF_Volume_1Eb ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            { Name svz ; NameOfCoef avz ; Function BF_Volume_1Ec ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }*/
            // { Name svz2 ; NameOfCoef avz2 ; Function BF_Volume_1Ed ;
            //    Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            /*{ Name svxa ; NameOfCoef avxa ; Function BF_VolumeX_1a ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            { Name svya ; NameOfCoef avya ; Function BF_VolumeY_1a ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            // { Name svza ; NameOfCoef avza ; Function BF_VolumeZ_1a ;
            //    Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            { Name svxb ; NameOfCoef avxb ; Function BF_VolumeX_1b ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            { Name svyb ; NameOfCoef avyb ; Function BF_VolumeY_1b ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            // { Name svzb ; NameOfCoef avzb ; Function BF_VolumeZ_1b ;
            //    Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            { Name svxc ; NameOfCoef avxc ; Function BF_VolumeX_1c ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }
            { Name svyc ; NameOfCoef avyc ; Function BF_VolumeY_1c ;
                Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }*/
            // { Name svzc ; NameOfCoef avzc ; Function BF_VolumeZ_1c ;
            //    Support MagnAnhyDomain ; Entity VolumesOf[ All ] ; }

        //}
        /*Constraint {
            { NameOfCoef aey; EntityType NodesOf; NameOfConstraint by; }
        }*/
    //}
    { Name b_or_h_space ; Type Form1; // To investigate
        BasisFunction {
            // { Name psif ; NameOfCoef bf ; Function BF_GradNode ;
            //    Support MagnAnhyDomain ; Entity NodesOf[ All ] ; }
            //  { Name gradpsin; NameOfCoef phin; Function BF_GradNode;
            // Support MagnAnhyDomain; Entity NodesOf[BndOmegaC]; } // Extend support to boundary for surface integration
            // { Name gradpsin; NameOfCoef phin2; Function BF_GroupOfEdges;
            //    Support Omega_h_OmegaC; Entity GroupsOfEdgesOnNodesOf[BndOmegaC]; }
            { Name psie; NameOfCoef he; Function BF_Edge;
                Support MagnAnhyDomain; Entity EdgesOf[All]; }
            // { Name gradpsin2; NameOfCoef phi2nd; Function BF_GradNode_2E; // For coupled formulation, if order of a is chosen not to be increased
            //    Support MagnAnhyDomain; Entity EdgesOf[All];}
        }
        Constraint {
            // { NameOfCoef bf; EntityType NodesOf; NameOfConstraint b; }
        }
    }
    /*{ Name b_or_h_space ; Type Form2P; // To investigate
        BasisFunction {
            { Name psif ; NameOfCoef bf ; Function BF_PerpendicularFacet ;
                Support MagnAnhyDomain ; Entity EdgesOf[ All ] ; }
             { Name psif2 ; NameOfCoef bf2 ; Function BF_PerpendicularFacet_2E ;
                Support MagnAnhyDomain ; Entity EdgesOf[ All ] ; }
        }
        Constraint {
            { NameOfCoef bf; EntityType FacetsOf; NameOfConstraint b; }
        }
    }*/
    // Function space for the magnetic vector potential a in b-conform formulation
    //  1: In 2D with in-plane b
    //      a = sum a_n * psi_n       (nodes in Omega_a)
    { Name a_space_2D; Type Form1P;
        BasisFunction {
            { Name psin; NameOfCoef an; Function BF_PerpendicularEdge;
                Support Omega_a_AndBnd; Entity NodesOf[All]; }
            // { Name psin3; NameOfCoef an3; Function BF_PerpendicularEdge_2E;
            //    Support OmegaC; Entity EdgesOf[OmegaC]; }
            If(a_enrichment == 1)
                { Name psin2; NameOfCoef an2; Function BF_PerpendicularEdge_2E;
                    Support Omega_a_AndBnd; Entity EdgesOf[BndOmega_ha]; } // Second order for stability of the coupling
            EndIf
        }
        Constraint {
            { NameOfCoef an; EntityType NodesOf; NameOfConstraint a; }
            If(a_enrichment == 1)
                { NameOfCoef an2; EntityType EdgesOf; NameOfConstraint a2; }
            EndIf
        }
    }
    //  2: In 3D or 2D with perpendicular b
    //      a = sum a_e * psi_e     (edges of co-tree in Omega_a)
    { Name a_space_3D; Type Form1;
        BasisFunction {
            { Name psie ; NameOfCoef ae ; Function BF_Edge ;
                Support Omega_a_AndBnd ; Entity EdgesOf[ All, Not BndOmegaC ] ; }
            { Name psie2 ; NameOfCoef ae2 ; Function BF_Edge ;
                Support Omega_a_AndBnd ; Entity EdgesOf[ BndOmegaC ] ; } // To keep all dofs of BndOmegaC where a is unique (because e is known)
            If(a_enrichment == 1)
                { Name psie3a ; NameOfCoef ae3a ; Function BF_Edge_3F_a ;
                    Support Omega_a_AndBnd ; Entity FacetsOf[ BndOmega_ha ] ; }
                { Name psie3b ; NameOfCoef ae3b ; Function BF_Edge_3F_b ;
                    Support Omega_a_AndBnd ; Entity FacetsOf[ BndOmega_ha ] ; }
                // { Name psie3c ; NameOfCoef ae3c ; Function BF_Edge_3F_c ;
                //    Support Omega_a_AndBnd ; Entity FacetsOf[ BndOmega_ha ] ; }
            EndIf
        }
        Constraint {
            { NameOfCoef ae; EntityType EdgesOf; NameOfConstraint a; }
            { NameOfCoef ae2; EntityType EdgesOf; NameOfConstraint a; }
            // Gauge condition
            { NameOfCoef ae; EntityType EdgesOfTreeIn; EntitySubType StartingOn;
                NameOfConstraint GaugeCondition; }
        }
    }
    { Name j_space_2D; Type Form1P;
        BasisFunction {
            { Name psin; NameOfCoef jn; Function BF_PerpendicularEdge;
                Support OmegaC; Entity NodesOf[OmegaC]; }
            // { Name psie; NameOfCoef je; Function BF_PerpendicularEdge_2E;
            //    Support OmegaC; Entity EdgesOf[OmegaC]; }
        }
        Constraint {
             { NameOfCoef jn; EntityType NodesOf; NameOfConstraint j; }
        }
    }
    /*{ Name j_space_2D ; Type Vector;
        BasisFunction {
             { Name svx ; NameOfCoef jn ; Function BF_VolumeZ ;
                Support OmegaC ; Entity VolumesOf[ OmegaC ] ; }
            // { Name svza ; NameOfCoef avza ; Function BF_VolumeZ_1a ;
            //    Support OmegaC ; Entity VolumesOf[ OmegaC ] ; }
            // { Name svzb ; NameOfCoef avzb ; Function BF_VolumeZ_1b ;
            //    Support OmegaC ; Entity VolumesOf[ OmegaC ] ; }
            // { Name svzc ; NameOfCoef avzc ; Function BF_VolumeZ_1c ;
            //    Support OmegaC ; Entity VolumesOf[ OmegaC ] ; }
        }
        Constraint {
             //{ NameOfCoef jn; EntityType VolumesOf; NameOfConstraint j; }
        }
    }*/
    { Name j_space_3D; Type Form1;
        BasisFunction {
            { Name psie ; NameOfCoef je ; Function BF_Edge ;
                Support OmegaC ; Entity EdgesOf[ OmegaC ] ; }
        }
        Constraint {
            { NameOfCoef je; EntityType EdgesOf; NameOfConstraint j; }
        }
    }
    // Function space for the electric scalar potential in b-conform formulation
    //  1: In 2D with in-plane b
    //      v = sum U_i * z_i        (connected conducting regions)
    { Name grad_v_space_2D; Type Form1P;
        BasisFunction {
            { Name zi; NameOfCoef Ui; Function BF_RegionZ;
                Support Region[OmegaC]; Entity Region[OmegaC]; }
        }
        GlobalQuantity {
            { Name U; Type AliasOf; NameOfCoef Ui; }
            { Name I; Type AssociatedWith; NameOfCoef Ui; }
        }
        Constraint {
            { NameOfCoef U;
                EntityType Region; NameOfConstraint Voltage; }
            { NameOfCoef I;
                EntityType Region; NameOfConstraint Current; }
        }
    }
    //  2: In 3D or 2D with perpendicular b
    //      v = sum V_i * v_i   (connected conducting regions)
    { Name grad_v_space_3D; Type Form1;
        BasisFunction {
            { Name vi; NameOfCoef Vi; Function BF_GradGroupOfNodes;
                Support ElementsOf[OmegaC, OnOneSideOf Electrodes];
                Entity GroupsOfNodesOf[Electrodes]; }
        }
        GlobalQuantity {
            { Name V; Type AliasOf; NameOfCoef Vi; }
            { Name I; Type AssociatedWith; NameOfCoef Vi; }
        }
        Constraint {
            { NameOfCoef V;
                EntityType GroupsOfNodesOf; NameOfConstraint Voltage; }
            { NameOfCoef I;
                EntityType GroupsOfNodesOf; NameOfConstraint Current; }
        }
    }
    // Function space for the curent vector potential in t-a-formulation
    // The function here is the normal component of the vector t. The normal direction is
    // introduced explicitly in the formulation, where the "true t" is Dof{t} * Normal[]
    //
    //  t = sum phi_n * psi_n     (nodes inside the tape)
    //      + sum T_i * psi_i     (global shape function linked to current intensity)
    //
    // NB: psi_i makes sense as a "global function" only in 3D. In 2D, this is simply one nodal function
    //      at the positive edge of the tape, but with the syntax below, all situations are treated the same way.
    { Name t_space; Type Form0;
        BasisFunction {
            { Name psin; NameOfCoef tn; Function BF_Node;
                Support Omega_h; Entity NodesOf[All, Not LateralEdges]; } // = 0 on lateral edges
            // { Name psin2; NameOfCoef tn2; Function BF_Node_2E;
            //    Support Omega_h; Entity EdgesOf[All, Not LateralEdges]; } // Leads to issues with Newton-Raphson -> Why?
            { Name psii; NameOfCoef Ti; Function BF_GroupOfNodes;
                Support Omega_h_OmegaC_AndBnd; Entity GroupsOfNodesOf[PositiveEdges]; }

        }
        GlobalQuantity {
            { Name T ; Type AliasOf        ; NameOfCoef Ti ; }
            { Name V ; Type AssociatedWith ; NameOfCoef Ti ; }
        }
        Constraint {
            { NameOfCoef V;
                EntityType GroupsOfNodesOf; NameOfConstraint Voltage; }
            { NameOfCoef T;
                EntityType GroupsOfNodesOf; NameOfConstraint Current; }
        }
    }
    // Function spaces for thin-shell model (Bruno de Sousa Alves)
    { Name HPhiTSSpace; Type Form1;
        BasisFunction {
            { Name sn; NameOfCoef phin; Function BF_GradNode;
                Support Region[{OmegaCC,GammaS}]; Entity NodesOf[OmegaCC, Not {GammaS}]; }

            { Name sn_u; NameOfCoef phin_u; Function BF_GradNode;
                Support Region[{OmegaCC,GammaS}]; Entity NodesOf[GammaS_1, Not LateralEdges]; } // Defined over \Gamma_s^+ only

            { Name sn_d; NameOfCoef phin_d; Function BF_GradNode;
                Support Region[{OmegaCC,GammaS}]; Entity NodesOf[GammaS_0, Not LateralEdges]; } // Defined over \Gamma_s^- only

            { Name sn_p; NameOfCoef phin_p; Function BF_GradNode; // Defined over the extreme points (edges) of the \Gamma_s, i.e. \partial\Gamma_s
                Support Region[{OmegaCC,GammaS}]; Entity NodesOf[LateralEdges]; }

            { Name sc1; NameOfCoef I; Function BF_GroupOfEdges; // Thick cut to impose current constraint in the shell
                Support Region[{OmegaCC,GammaS}]; Entity GroupsOfEdgesOf[Cuts]; }
        }
        GlobalQuantity {
            { Name Current ; Type AliasOf        ; NameOfCoef I ; }
            { Name Voltage ; Type AssociatedWith ; NameOfCoef I ; }
        }
        SubSpace {
            { Name GammaS_up; NameOfBasisFunction {sn_u,sc1,sn_p}; } // includes grad(phi) in \Gamma_s^+ and in its edges, and the thick cut (if it is thouching \Gamma_s^+)
            { Name GammaS_down;   NameOfBasisFunction {sn_d,sc1,sn_p}; } // includes grad(phi) in \Gamma_s^- and in its edges, and the thick cut (if it is thouching \Gamma_s^-)
        }
        Constraint {
            { NameOfCoef phin; EntityType NodesOf; NameOfConstraint phi; } // For applied field
            { NameOfCoef Current ;
                EntityType GroupsOfEdgesOf ; NameOfConstraint Current ; }
            { NameOfCoef Voltage ;
                EntityType GroupsOfEdgesOf ; NameOfConstraint Voltage ; }
        }

    }
    // Inside the thin shell
    For i In {1:N_ele}
        { Name HPhiTSSpace~{i} ; Type Form1 ;
            BasisFunction {
            { Name se ; NameOfCoef he~{i} ; Function BF_Edge ;
                Support GammaS_0 ; Entity EdgesOf[ All ] ; } // Defined on \Gamma_s^- only
            }
        }
    EndFor
    // Inside the thin shell
    { Name HPhiTSSpace~{N_ele+1} ; Type Form1 ;
        BasisFunction {
            { Name se ; NameOfCoef he~{N_ele+1} ; Function BF_Edge ;
            Support GammaS ; Entity EdgesOf[ All ] ; } // Defined on \Gamma_s=\Gamma_s^+ \cup \Gamma_s^-
        }
        Constraint {
            { NameOfCoef he~{N_ele+1} ;
            EntityType EdgesOf ; NameOfConstraint Connect ; } // Link constraint with coefficient 1
        }
    }
}

// ----------------------------------------------------------------------------
// --------------------------- FORMULATION ------------------------------------
// ----------------------------------------------------------------------------
mult_aj = mu0^(8);

Formulation {
    // h-formulation
    { Name MagDyn_htot; Type FemEquation;
        Quantity {
            { Name h; Type Local; NameOfSpace h_space; }
            { Name hp; Type Local; NameOfSpace h_space; }
            If(alt_formulation == 1)
                { Name b; Type Local; NameOfSpace b_or_h_space; }
                { Name bp; Type Local; NameOfSpace b_or_h_space; }
            EndIf
            If(Flag_hs == 1)
                { Name hs; Type Local; NameOfSpace h_space[hs]; }
            EndIf
            { Name I; Type Global; NameOfSpace h_space[I]; }
            { Name V; Type Global; NameOfSpace h_space[V]; }
        }
        Equation {
            // Keeping track of Dofs in auxiliar line of MB if Symmetry==1 (DO NOT REMOVE!)
            If(Flag_MB==1)
                Galerkin {  [  0*Dof{h} , {h} ]  ;
                    In Rotor_Bnd_MBaux; Jacobian Sur; Integration Int; }
            EndIf
            // Time derivative of b (NonMagnDomain)
            Galerkin { [ mu[] * Dof{h} / $DTime , {h} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            Galerkin { [ - mu[] * {h}[1] / $DTime , {h} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            // Time derivative of b (MagnAnhyDomain)
            If(alt_formulation == 1)
                Galerkin { [ Dof{b} / $DTime , {h} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - {b}[1] / $DTime , {h} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ Dof{h} , {b} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
                Galerkin { [ - nu[{b}] * {b} , {b} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol; }
                Galerkin { [ - dhdb[{b}] * Dof{b} , {bp} ]; // bp to avoid auto-symmetrization by GetDP!
                    In MagnAnhyDomain; Integration Int; Jacobian Vol; }
                Galerkin { [ + dhdb[{b}] * {b} , {bp} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol; }
            Else
                If(Flag_h_NR_Mu)
                    Galerkin { [ mu[{h}] * {h} / $DTime , {h} ];
                        In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
                    Galerkin { [ dbdh[{h}] * Dof{h} / $DTime , {hp}]; // hp to avoid auto-symmetrization by GetDP!
                        In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
                    Galerkin { [ - dbdh[{h}] * {h}  / $DTime , {hp}];
                        In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
                Else
                    Galerkin { [ mu[{h}] * Dof{h} / $DTime , {h} ];
                        In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
                EndIf
                Galerkin { [ - mu[{h}[1]] * {h}[1] / $DTime , {h} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol;  }
            EndIf
            // Induced current (NonLinOmegaC)
            If(Flag_h_NR_Rho)
                If(Flag_jcb == 0 || Homogenized == 0)
                    Galerkin { [ rho[{d h}, mu0*Norm[{h}] ] * {d h} , {d h} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                    Galerkin { [ dedj[{d h},mu0*Norm[{h}] ] * Dof{d h} , {d hp} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
                    Galerkin { [ - dedj[{d h},mu0*Norm[{h}]] * {d h} , {d hp} ];
                        In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
                Else
                    // Do not look at this: particular case when jc(b) in specific anisotropic problem (stacked tapes shield).
                    Galerkin { [ rho[{d h}, Norm[Vector[ mu0*CompX[{h}], CompY[mu[{h}] * {h}], mu0*CompZ[{h}] ] ] ] * {d h} , {d h} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                    Galerkin { [ dedj[{d h}, Norm[Vector[ mu0*CompX[{h}], CompY[mu[{h}] * {h}], mu0*CompZ[{h}] ] ] ] * Dof{d h} , {d hp} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
                    Galerkin { [ - dedj[{d h}, Norm[Vector[ mu0*CompX[{h}], CompY[mu[{h}] * {h}], mu0*CompZ[{h}] ] ] ] * {d h} , {d hp} ];
                        In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
                EndIf
            Else
                Galerkin { [ rho[{d h}, mu0*Norm[{h}]] * Dof{d h} , {d h} ];
                    In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            EndIf
            // Induced current (LinOmegaC)
            Galerkin { [ rho[] * Dof{d h} , {d h} ];
                In LinOmegaC; Integration Int; Jacobian Vol;  }
            If(Flag_hs == 1 && Flag_spurious_conductivity == 1)
                Galerkin { [ -rho[] * Dof{d hs} , {d h} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
            EndIf
            // Induced currents (Global variables)
            GlobalTerm { [ Dof{V} , {I} ] ; In Cuts ; }
            // Example of surface term for natural condition (be careful!)
            //If(SourceType == 3)
            //    Galerkin { [ - (bs_bnd[] - bs_bnd_prev[])/$DTime * Normal[] , {dInv h} ];
            //        In Gamma_e; Integration Int; Jacobian Sur;  }
            //EndIf
        }
    }
    // a-v-formulation, total potential
    { Name MagDyn_avtot; Type FemEquation;
        Quantity {
            If(Dim == 1 || Dim == 2)
                { Name a; Type Local; NameOfSpace a_space_2D; }
                { Name ap; Type Local; NameOfSpace a_space_2D; }
                { Name ur; Type Local; NameOfSpace grad_v_space_2D; }
                { Name I; Type Global; NameOfSpace grad_v_space_2D [I]; }
                { Name U; Type Global; NameOfSpace grad_v_space_2D [U]; }
                If(alt_formulation == 1)
                    { Name j; Type Local; NameOfSpace j_space_2D; } // Experimental
                EndIf
            ElseIf(Dim == 3)
                { Name a; Type Local; NameOfSpace a_space_3D; }
                { Name ap; Type Local; NameOfSpace a_space_3D; }
                { Name ur; Type Local; NameOfSpace grad_v_space_3D; }
                { Name I; Type Global; NameOfSpace grad_v_space_3D [I]; }
                { Name U; Type Global; NameOfSpace grad_v_space_3D [V]; }
                If(alt_formulation == 1)
                    { Name j; Type Local; NameOfSpace j_space_3D; } // Experimental
                EndIf
            EndIf
        }
        Equation {
            // Keeping track of Dofs in auxiliar line of MB if Symmetry==1 (DO NOT REMOVE!)
            If(Flag_MB==1)
              Galerkin {  [  0*Dof{d a} , {d a} ]  ;
                In Rotor_Bnd_MBaux; Jacobian Sur; Integration Int; }
            EndIf
            // Curl h term - NonMagnDomain
            Galerkin { [ nu[] * Dof{d a} , {d a} ];
                In MagnLinDomain; Integration Int; Jacobian Vol; }
            // Curl h term - MagnAnhyDomain
            If(Flag_a_NR_Nu)
                Galerkin { [ nu[{d a}] * {d a} , {d a} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol; }
                Galerkin { [ dhdb[{d a}] * Dof{d a} , {d ap} ]; // hp to avoid auto-symmetrization by GetDP!
                    In MagnAnhyDomain; Integration Int; Jacobian Vol; }
                Galerkin { [ - dhdb[{d a}] * {d a} , {d ap} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol; }
            Else
                Galerkin { [ nu[{d a}] * Dof{d a}, {d a} ];
                    In MagnAnhyDomain; Integration Int; Jacobian Vol; }
            EndIf
            // Induced currents
            If(alt_formulation == 0)
                // Non-linear OmegaC
                If(Flag_a_NR_Sigma) // Very difficult to converge. Use Picard iteration instead.
                    Galerkin { [ - sigmae[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}]], {a} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                    Galerkin { [ - sigmae[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}]], {ur} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }

                    Galerkin { [ djde[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}] ] * Dof{a}/$DTime , {a} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
                    Galerkin { [ - djde[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}] ] * {a}/$DTime , {a} ];
                        In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
                    Galerkin { [ djde[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}] ] * Dof{ur} , {a} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
                    Galerkin { [ - djde[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}] ] * {ur} , {a} ];
                        In NonLinOmegaC ; Integration Int; Jacobian Vol;  }

                    Galerkin { [ djde[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}] ] * Dof{a}/$DTime , {ur} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
                    Galerkin { [ - djde[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}] ] * {a}/$DTime , {ur} ];
                        In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
                    Galerkin { [ djde[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}] ] * Dof{ur} , {ur} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  } // Dof appears linearly
                    Galerkin { [ - djde[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}] ] * {ur} , {ur} ];
                        In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
                Else
                    Galerkin { [ sigma[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}]] * Dof{a} / $DTime , {a} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                    Galerkin { [ - sigma[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}]] * {a}[1] / $DTime ,  {a} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }

                    Galerkin { [ sigma[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}]] * Dof{ur} , {a} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }

                    Galerkin { [ sigma[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}]] * Dof{a} / $DTime , {ur} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                    Galerkin { [ - sigma[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}]] * {a}[1] / $DTime ,  {ur} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }

                    Galerkin { [ sigma[ (- {a} + {a}[1]) / $DTime - {ur}, Norm[{d a}]] * Dof{ur} , {ur} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                EndIf
                // Linear OmegaC
                Galerkin { [ sigma[] * Dof{a} / $DTime , {a} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ - sigma[] * {a}[1] / $DTime ,  {a} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ sigma[] * Dof{ur} , {a} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ sigma[] * Dof{a} / $DTime , {ur} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ - sigma[] * {a}[1] / $DTime ,  {ur} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ sigma[] * Dof{ur} , {ur} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
            Else
                // To complete correctly (to be checked)
                Galerkin { [ - Dof{j} , {a} ];
                    In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                If(Flag_jcb == 0 || Homogenized == 0)
                    Galerkin { [ rho[{j}, Norm[{d a}] ] * {j} , {j} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                    Galerkin { [ dedj[{j}, Norm[{d a}] ] * Dof{j} , {j} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                    Galerkin { [ - dedj[{j}, Norm[{d a}]] * {j} , {j} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                Else
                    // Do not look at this: particular case when jc(b) in specific anisotropic problem (stacked tapes shield).
                    Galerkin { [ rho[{j}, Norm[ Vector[ mu0*CompX[nu[{d a}] * {d a}], CompY[{d a}], mu0*CompZ[nu[{d a}] * {d a}] ] ] ] * {j} , {j} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                    Galerkin { [ dedj[{j}, Norm[ Vector[ mu0*CompX[nu[{d a}] * {d a}], CompY[{d a}], mu0*CompZ[nu[{d a}] * {d a}] ] ] ] * Dof{j} , {j} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                    Galerkin { [ - dedj[{j}, Norm[ Vector[ mu0*CompX[nu[{d a}] * {d a}], CompY[{d a}], mu0*CompZ[nu[{d a}] * {d a}] ] ] ] * {j} , {j} ];
                        In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                EndIf
                Galerkin { [ Dof{a} / $DTime , {j} ];
                    In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ - {a}[1] / $DTime ,  {j} ];
                    In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ Dof{ur} , {j} ];
                    In NonLinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ - mult_aj*Dof{j} , {ur} ];
                    In NonLinOmegaC; Integration Int; Jacobian Vol;  }

                Galerkin { [ - Dof{j} , {a} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ rho[] * Dof{j} , {j} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ Dof{a} / $DTime , {j} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ - {a}[1] / $DTime ,  {j} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ Dof{ur} , {j} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
                Galerkin { [ - mult_aj*Dof{j} , {ur} ];
                    In LinOmegaC; Integration Int; Jacobian Vol;  }
            EndIf
            // Stranded conductor region (belongs to OmegaCC)
            Galerkin { [ -js[] , {a} ];
                In OmegaC_stranded; Integration Int; Jacobian Vol;  }
            // Global term
            If(Dim == 1 || Dim == 2)// && alt_formulation == 0) // To fix: alt_formulation does not work with global variables!
                If(alt_formulation == 1)
                    GlobalTerm { [ mult_aj*Dof{I}  , {U} ]; In OmegaC; }
                Else
                    GlobalTerm { [ Dof{I}  , {U} ]; In OmegaC; }
                EndIf
            ElseIf(Dim == 3)
                Galerkin { [ - hsVal[] * (directionApplied[] /\ Normal[]), {a} ];
                    In Gamma_h ; Integration Int ; Jacobian Sur; }
                If(alt_formulation == 1)
                    GlobalTerm { [ mult_aj*Dof{I}  , {U} ]; In Electrodes; }
                Else
                    GlobalTerm { [ Dof{I}  , {U} ]; In Electrodes; }
                EndIf
            EndIf
        }
    }
    // Coupled formulation
    { Name MagDyn_coupled; Type FemEquation;
        Quantity {
            { Name h; Type Local; NameOfSpace h_space; }
            { Name hp; Type Local; NameOfSpace h_space; }
            { Name I; Type Global; NameOfSpace h_space[I]; }
            { Name V; Type Global; NameOfSpace h_space[V]; }
            If(Dim == 3)
                { Name a; Type Local; NameOfSpace a_space_3D; }
                { Name ap; Type Local; NameOfSpace a_space_3D; }
            Else
                { Name a; Type Local; NameOfSpace a_space_2D; }
                { Name ap; Type Local; NameOfSpace a_space_2D; }
            EndIf
        }
        Equation {
            // Keeping track of Dofs in auxiliar line of MB if Symmetry==1 (DO NOT REMOVE!)
            If(Flag_MB==1)
              Galerkin {  [  0*Dof{d a} , {d a} ]  ;
                In Rotor_Bnd_MBaux; Jacobian Sur; Integration Int; }
            EndIf
            // ---- H-FORMULATION (contains nonlinear conducting domain) ----
            // Time derivative - current solution
            Galerkin { [ mu[] * Dof{h} / $DTime , {h} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            // Time derivative - previous solution
            //Galerkin { [ - ($TimeStep == 1) * mu[] * h_fromFile[] / $DTime , {h} ];
            //    In MagnLinDomain; Integration Int; Jacobian Vol;  }
            Galerkin { [ - mu[] * {h}[1] / $DTime , {h} ];
                In MagnLinDomain; Integration Int; Jacobian Vol;  }
            // Induced currents
            // Non-linear OmegaC
            Galerkin { [ rho[{d h}, mu[]*Norm[{h}] ] * {d h} , {d h} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { [ dedj[{d h}, mu[]*Norm[{h}] ] * Dof{d h} , {d hp} ];
                In NonLinOmegaC; Integration Int; Jacobian Vol;  }
            Galerkin { [ - dedj[{d h}, mu[]*Norm[{h}] ] * {d h} , {d hp} ];
                In NonLinOmegaC ; Integration Int; Jacobian Vol;  }
            // Linear OmegaC
            Galerkin { [ rho[] * Dof{d h} , {d h} ];
                In LinOmegaC; Integration Int; Jacobian Vol;  }
            // Global constraint
            GlobalTerm { [ Dof{V} , {I} ] ; In Cuts ; }
            // ---- A-FORMULATION (contains nonlinear magnetic domain) ----
            // Curl h term - NonMagnDomain
            Galerkin { [ nu[] * Dof{d a} , {d a} ];
                In MagnLinDomain; Integration Int; Jacobian Vol; }
            // Curl h term - MagnAnhyDomain
            Galerkin { [ nu[{d a}] * {d a} , {d a} ];
                In MagnAnhyDomain; Integration Int; Jacobian Vol; }
            Galerkin { [ dhdb[{d a}] * Dof{d a} , {d ap} ];
                In MagnAnhyDomain; Integration Int; Jacobian Vol; }
            Galerkin { [ - dhdb[{d a}] * {d a} , {d ap} ];
                In MagnAnhyDomain; Integration Int; Jacobian Vol; }
            // Current density (possible linear conducting domain in Omega_a)
            // TBC ... (not done yet)
            // Stranded conductor region (belongs to OmegaCC)
            Galerkin { [ -js[] , {a} ];
                In OmegaC_stranded; Integration Int; Jacobian Vol;  }
            // ---- COUPLING ----
            /*Galerkin { [ - Dof{d a} * Normal[] / $DTime , {dInv h}];
                In BndOmega_ha; Integration Int; Jacobian Sur; }
            Galerkin { [ {d a}[1] * Normal[] /$DTime , {dInv h}];
                In BndOmega_ha; Integration Int; Jacobian Sur; }*/

            Galerkin { [ + Flag_NormalSign * Dof{a} /\ Normal[] /$DTime , {h}];
                In BndOmega_ha; Integration Int; Jacobian Sur; }
            //Galerkin { [ - (($TimeStep == 1) * Flag_NormalSign * a_fromFile[] /\ Normal[] /$DTime) , {h}];
            //    In BndOmega_ha; Integration Int; Jacobian Sur; }
            Galerkin { [ - Flag_NormalSign * {a}[1] /\ Normal[] /$DTime , {h}];
                In BndOmega_ha; Integration Int; Jacobian Sur; }
            Galerkin { [ Flag_NormalSign * Dof{h} /\ Normal[] , {a}];
                In BndOmega_ha; Integration Int; Jacobian Sur; } // Sign for normal (should be -1 but normal is opposite)
            If(Dim == 3)
                Integral { [ - hsVal[] * (directionApplied[] /\ Normal[]), {a} ];
                    In Gamma_h ; Integration Int ; Jacobian Sur; } // TO CHECK
                // Do not integrate on the part of bnd that is in Omega_h (and not in Omega_a)
                // Or, define the completely rigorous function space (that would be more general) TODO!
            EndIf
        }
    }
    // t-a-formulation.
    // We actually solve for t_tilde = w * t
    // (so the thickness is already inside t, such that BC are directly the current intensity)
    { Name MagDyn_ta; Type FemEquation;
        Quantity {
            { Name t; Type Local; NameOfSpace t_space; }
            { Name T; Type Global; NameOfSpace t_space[T]; }
            { Name V; Type Global; NameOfSpace t_space[V]; }
            If(Dim == 3)
                { Name a; Type Local; NameOfSpace a_space_3D; }
            Else
                { Name a; Type Local; NameOfSpace a_space_2D; }
            EndIf
        }
        Equation {
            // Time derivative - current solution
            Galerkin { [ - Normal[] /\ Dof{a} , {d t} ];
                In OmegaC; Integration Int; Jacobian Sur;  }
            // Time derivative - previous solution
            Galerkin { [ Normal[] /\ {a}[1] , {d t} ];
                In OmegaC; Integration Int; Jacobian Sur;  }
            // ---- SUPER ----
            // Induced currents
            // Non-linear OmegaC
            If(Flag_h_NR_Rho)
                Galerkin { [ - $DTime * 1./thickness[] * rho[1./thickness[] *{d t} /\ Normal[], Norm[{d a}] ] * Normal[] /\ ({d t} /\ Normal[]) , {d t} ];
                    In NonLinOmegaC; Integration Int; Jacobian Sur;  }
                Galerkin { [ - $DTime * 1./thickness[] * Normal[] /\ (dedj[1./thickness[] *{d t} /\ Normal[], Norm[{d a}] ] * (Dof{d t} /\ Normal[])) , {d t} ];
                    In NonLinOmegaC; Integration Int; Jacobian Sur;  }
                Galerkin { [ $DTime * 1./thickness[] * Normal[] /\ (dedj[1./thickness[] *{d t} /\ Normal[], Norm[{d a}] ] * ({d t} /\ Normal[])) , {d t} ];
                    In NonLinOmegaC ; Integration Int; Jacobian Sur;  }
            Else
                Galerkin { [ - $DTime * 1./thickness[] * rho[1./thickness[] *{d t} /\ Normal[], Norm[{d a}] ] * Normal[] /\ (Dof{d t} /\ Normal[]) , {d t} ];
                    In NonLinOmegaC; Integration Int; Jacobian Sur;  }
            EndIf
            // Linear OmegaC
            Galerkin { [ - $DTime * 1./thickness[] * rho[] * Normal[] /\ (Dof{d t} /\ Normal[]) , {d t} ];
                In LinOmegaC; Integration Int; Jacobian Sur;  }
            GlobalTerm { [ - $DTime * Dof{V} , {T} ] ; In PositiveEdges ; }
            // ---- FERRO ----
            // Curl h term - NonMagnDomain
            Galerkin { [ nu[] * Dof{d a} , {d a} ];
                In Omega_a; Integration Int; Jacobian Vol; }
            // Curl h term - MagnAnhyDomain (only Newton-Raphson)
            Galerkin { [ nu[{d a}] * {d a} , {d a} ];
                In MagnAnhyDomain; Integration Int; Jacobian Vol; }
            Galerkin { [ dhdb[{d a}] * Dof{d a} , {d a} ];
                In MagnAnhyDomain; Integration Int; Jacobian Vol; }
            Galerkin { [ - dhdb[{d a}] * {d a} , {d a} ];
                In MagnAnhyDomain; Integration Int; Jacobian Vol; }
            // Surface term
            Galerkin { [ - Dof{d t} /\ Normal[] , {a}]; // Dof{d t} /\ Normal[] is the current density!
                In BndOmega_ha; Integration Int; Jacobian Sur; }
            If(Dim == 3)
                Galerkin { [ - hsVal[] * (directionApplied[] /\ Normal[]), {a} ];
                    In Gamma_h ; Integration Int ; Jacobian Sur; }
            EndIf
        }
    }
    // h-phi-ts-formulation (Bruno de Sousa Alves)
    { Name MagDyn_hphits; Type FemEquation;
        Quantity {
            { Name h; Type Local; NameOfSpace HPhiTSSpace; }
            { Name I; Type Global; NameOfSpace HPhiTSSpace[Current]; }
            { Name V; Type Global; NameOfSpace HPhiTSSpace[Voltage]; }

            { Name hi~{0}; Type Local; NameOfSpace HPhiTSSpace[GammaS_down]; }
            For i In {1:N_ele+1}
                { Name hi~{i}  ; Type Local ; NameOfSpace HPhiTSSpace~{i} ; }
            EndFor
            { Name hi~{N_ele+2}; Type Local; NameOfSpace HPhiTSSpace[GammaS_up]; }

        }

        Equation {
            Galerkin { [ mu[] * Dof{h} / $DTime , {h} ];
            In OmegaCC; Integration Int; Jacobian Vol;} // WARNING: To change if we add non thin-shell conducting domains

            Galerkin { [ - mu[] * {h}[1] / $DTime , {h} ]; // IDEM
            In OmegaCC; Integration Int; Jacobian Vol;}

            GlobalTerm { [ Dof{V} , {I} ] ; In Cuts ; }

            //Galerkin { [ rho[] * Dof{d h} , {d h} ];
            //In OmegaC; Integration Int; Jacobian Vol;  }

            // TS model
            For i In {0:N_ele+1}
                If (i==0 || i== N_ele+1) //explicitly connect h=-\grad(\phi) (to improve)

                    Galerkin {  [ Dof{hi~{i}} , {hi~{i}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Galerkin {  [ - Dof{hi~{i}} , {hi~{i+1}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Galerkin {  [ - Dof{hi~{i+1}} , {hi~{i}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Galerkin {  [ Dof{hi~{i+1}} , {hi~{i+1}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}
                Else

                    Galerkin {  [ 2 * mu0 * Delta/6 * Dof{hi~{i}} / $DTime , {hi~{i}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Galerkin {  [  mu0 * Delta/6 * Dof{hi~{i}} / $DTime , {hi~{i+1}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Galerkin {  [  mu0 * Delta/6 * Dof{hi~{i+1}} / $DTime , {hi~{i}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Galerkin {  [ 2 * mu0 * Delta/6 * Dof{hi~{i+1}} / $DTime , {hi~{i+1}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Galerkin {  [ - 2 * mu0 * Delta/6 * {hi~{i}}[1] / $DTime , {hi~{i}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Galerkin {  [ - mu0 * Delta/6 * {hi~{i}}[1] / $DTime , {hi~{i+1}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Galerkin {  [ - mu0 * Delta/6 * {hi~{i+1}}[1] / $DTime , {hi~{i}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Galerkin {  [ - 2 * mu0 * Delta/6 * {hi~{i+1}}[1] / $DTime , {hi~{i+1}} ];
                    In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}


                    If (Flag_LinearProblem==1) // rho linear
                        Galerkin {  [ 1/Delta * rho_copper[] * Dof{hi~{i}} , {hi~{i}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;} // it will be always integrated over Gamma_s^0 in this case.

                        Galerkin {  [ - 1/Delta * rho_copper[] * Dof{hi~{i}} , {hi~{i+1}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ - 1/Delta * rho_copper[] * Dof{hi~{i+1}} , {hi~{i}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ 1/Delta * rho_copper[] * Dof{hi~{i+1}} , {hi~{i+1}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    Else // nonlinear case with power-law linearization
                        Galerkin {  [ 1/Delta * rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i}} , {hi~{i}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ - 1/Delta * rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i}} , {hi~{i+1}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ - 1/Delta * rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i+1}} , {hi~{i}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ 1/Delta * rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i+1}} , {hi~{i+1}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}


                        Galerkin {  [ 1/Delta * dedj_powerTS[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i}} , {hi~{i}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ - 1/Delta * dedj_powerTS[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i}} , {hi~{i+1}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ - 1/Delta * dedj_powerTS[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i+1}} , {hi~{i}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ 1/Delta * dedj_powerTS[{hi~{i}},{hi~{i+1}}] * Dof{hi~{i+1}} , {hi~{i+1}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}


                        Galerkin {  [ -1/Delta * dedj_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i}} , {hi~{i}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [  1/Delta * dedj_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i}} , {hi~{i+1}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [  1/Delta * dedj_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i+1}} , {hi~{i}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                        Galerkin {  [ -1/Delta * dedj_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i+1}} , {hi~{i+1}} ];
                        In GammaS~{(i<N_ele+1)? 0:1}; Integration Int; Jacobian Sur;}

                    EndIf
                EndIf
            EndFor

        }
    }
}

// ----------------------------------------------------------------------------
// --------------------------- POST-PROCESSING --------------------------------
// ----------------------------------------------------------------------------
PostProcessing {
    // h-formulation, total field
    { Name MagDyn_htot; NameOfFormulation MagDyn_htot;
        Quantity {
            { Name phi; Value{ Local{ [ {dInv h} ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name h; Value{ Local{ [ {h} ] ;
                In Omega; Jacobian Vol; } } }
            // { Name h_xi; Value{ Local{ [ JtransFull[]*{h} ] ;
            //    In Omega; Jacobian Vol; } } }
            { Name b; Value {
                Term { [ mu[] * {h} ] ; In MagnLinDomain; Jacobian Vol; }
                Term { [ mu[{h}] * {h} ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            If(alt_formulation == 1)
                { Name b_alt; Value {
                    Term { [ {b} ] ; In MagnAnhyDomain; Jacobian Vol; }
                    //Term { [ mu[] * {h} ] ; In MagnLinDomain; Jacobian Vol; }
                    }
                }
                { Name h_test; Value {
                    Term { [ nu[mu[{h}] * {h}] * (mu[{h}] * {h}) ] ; In MagnAnhyDomain; Jacobian Vol; }
                    //Term { [ mu[] * {h} ] ; In MagnLinDomain; Jacobian Vol; }
                    }
                }
                { Name h_alt; Value {
                    Term { [ nu[{b}] * {b} ] ; In MagnAnhyDomain; Jacobian Vol; }
                    //Term { [ {h} ] ; In MagnLinDomain; Jacobian Vol; }
                    }
                }
            EndIf
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
            { Name mur; Value{ Local{ [ mu[{h}]/mu0 ] ;// InterpolationAkima[Norm[{h}]]{List[mur_data]} ] ;  //
                In MagnAnhyDomain; Jacobian Vol; } } }
            // Home-made GetDP function -> not publicly available yet.
            // { Name mur_stack; Value{ Local{ [ hAvgToMuhFerro[{h}, factor]{List[mur_data]} ] ;// InterpolationAkima[Norm[{h}]]{List[mur_data]} ] ;  //
            //    In MagnAnhyDomain; Jacobian Vol; } } }
            { Name j; Value{ Local{ [ {d h} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name js; Value{ Local{ [ {d h} ] ;
                In OmegaC_stranded; Jacobian Vol; } } }
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
                    If(alt_formulation == 0)
                        Integral{ [ (mu[{h}]*{h} - mu[{h}[1]]*{h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                            In MagnAnhyDomain ; Integration Int ; Jacobian Vol; }
                    Else
                        Integral{ [ ({b} - {b}[1]) / $DTime * (nu[{b}]*{b}+nu[{b}[1]]*{b}[1])/2 ] ;
                            In MagnAnhyDomain ; Integration Int ; Jacobian Vol; }
                    EndIf
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
    // a-v-formulation, total potential
    { Name MagDyn_avtot; NameOfFormulation MagDyn_avtot;
        Quantity {
            { Name a; Value{ Local{ [ {a} ] ;
                In Omega; Jacobian Vol; } } }
            { Name az; Value{ Local{ [ CompZ[{a}] ] ;
                In Omega; Jacobian Vol; } } }
            { Name b; Value{ Local{ [ {d a} ] ;
                In Omega; Jacobian Vol; } } }
            { Name mur; Value{ Local{ [ 1.0/(nu[{d a}] * mu0) ] ;
                In MagnAnhyDomain; Jacobian Vol; } } }
            { Name h; Value {
                Term { [ nu[] * {d a} ] ; In MagnLinDomain; Jacobian Vol; }
                Term { [ nu[{d a}] * {d a} ] ; In MagnAnhyDomain; Jacobian Vol; }
                }
            }
            { Name e; Value{ Local{ [ - Dt[{a}] - {ur} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name ur; Value{ Local{ [ {ur} ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name j; Value{ Local{ [ sigmae[ - Dt[{a}] - {ur} , {d a}] ] ;
                In OmegaC; Jacobian Vol; } } }
            If(alt_formulation == 1)
                { Name j_alt; Value{ Local{ [ {j} ] ;
                    In OmegaC; Jacobian Vol; } } }
                { Name jz_alt; Value{ Local{ [ CompZ[{j}] ] ;
                    In OmegaC; Jacobian Vol; } } }
                { Name jouleLosses; Value{ Local{ [ {j} * (- Dt[{a}] - {ur}) ] ;
                        In OmegaC; Jacobian Vol; } } }
            Else
                { Name jouleLosses; Value{ Local{ [ sigmae[ - Dt[{a}] - {ur} , {d a}] * (- Dt[{a}] - {ur}) ] ;
                        In OmegaC; Jacobian Vol; } } }
            EndIf
            { Name js; Value{ Local{ [ js[] ] ;
                In OmegaC_stranded; Jacobian Vol; } } }
            { Name jnorm; Value{ Local{ [ Norm[sigmae[ - Dt[{a}] - {ur} , {d a}]] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name jz; Value{ Local{ [ CompZ[sigmae[ - Dt[{a}] - {ur}, {d a} ]] ] ;
                In OmegaC; Jacobian Vol; } } }
            { Name I; Value{ Term{ [ {I} ] ;
                In OmegaC; } } }
            { Name U; Value{ Term{ [ {U} ] ;
                In OmegaC; } } }
            If(Axisymmetry == 1)
                { Name m_avg; Value{ Integral{ [ 2*Pi * 0.5 * XYZ[]
                    /\ sigmae[ (- {a} + {a}[1]) / $DTime - {ur}, {d a} ] / (Pi * SurfaceArea[] * W/2) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
                { Name m_avg_y_tesla; Value{ Integral{ [ mu0*2*Pi * 0.5 * Vector[0,1,0] * (XYZ[]
                    /\ sigmae[ (- {a} + {a}[1]) / $DTime - {ur} , {d a}]) / (Pi * SurfaceArea[] * W/2) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
            ElseIf(Dim == 1)
                // TBC...
            ElseIf(Dim == 2)
                // Not axisym, so surface integral to give (total) magnetization per unit length.
                // Here, the average is computed. ATTENTION: Factor 2 (for end junctions) is not introduced
                { Name m_avg; Value{ Integral{ [ 0.5 * XYZ[]
                    /\ sigmae[ (- {a} + {a}[1]) / $DTime - {ur}, {d a} ] / (SurfaceArea[]) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
                { Name m_avg_y_tesla; Value{ Integral{ [ mu0*0.5 * Vector[0,1,0] * (XYZ[]
                    /\ sigmae[ (- {a} + {a}[1]) / $DTime - {ur} , {d a}]) / (SurfaceArea[]) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
                { Name m_avg_x_tesla; Value{ Integral{ [ mu0*0.5 * Vector[1,0,0] * (XYZ[]
                    /\ sigmae[ (- {a} + {a}[1]) / $DTime - {ur}, {d a} ]) / (SurfaceArea[]) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
            ElseIf(Dim == 3)
                { Name m_avg; Value{ Integral{ [ 0.5 * XYZ[]
                    /\ sigmae[ (- {a} + {a}[1]) / $DTime - {ur}, {d a} ] / (GetVolume[]) ] ;
                    In OmegaC; Integration Int; Jacobian Vol; } } }
            EndIf
            { Name hsVal; Value{ Term { [ hsVal[] ]; In Omega; } } }
            { Name bsVal; Value{ Term { [ mu0*hsVal[] ]; In Omega; } } }
            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }
            If(Flag_MB == 1)
                { Name rotor_angle; Value{ Term { [ 180/Pi*omega*$Time ]; In Omega; } } }
            EndIf
            { Name power; // (b+b[1])/2 instead of b -> to avoid a constant sign error accumulation
                Value{
                    Integral{ [ ({d a} - {d a}[1]) / $DTime * nu[{d a}] * ({d a}+{d a}[1])/2 ] ;
                        In MagnAnhyDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [ ({d a} - {d a}[1]) / $DTime * nu[] * ({d a}+{d a}[1])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    If(alt_formulation == 0)
                        Integral{ [sigma[ (- {a} + {a}[1]) / $DTime - {ur}, {d a}]
                            * ((- {a} + {a}[1]) / $DTime - {ur} ) * ((- {a} + {a}[1]) / $DTime - {ur} )] ;
                            In OmegaC ; Integration Int ; Jacobian Vol; }
                    Else
                        Integral{ [rho[{j}, Norm[{d a}] ] * {j} * {j}] ;
                            In OmegaC ; Integration Int ; Jacobian Vol; }
                    EndIf
                }
            }
            { Name dissPowerGlobal;
                Value{
                    Term{ [ {U}*{I} ] ; In OmegaC;}
                }
            }
            { Name dissPower;
                Value{
                    If(alt_formulation == 0)
                        Integral{ [sigma[ (- {a} + {a}[1]) / $DTime - {ur}, {d a}]
                            * ((- {a} + {a}[1]) / $DTime - {ur} ) * ((- {a} + {a}[1]) / $DTime - {ur} )] ;
                            In OmegaC ; Integration Int ; Jacobian Vol; }
                    Else
                        Integral{ [rho[{j}, Norm[{d a}] ] * {j} * {j}] ;
                            In OmegaC ; Integration Int ; Jacobian Vol; }
                    EndIf
                }
            }
            If(Flag_MB==1)
                { Name torqueMaxwell ;
                  // Torque computation via Maxwell stress tensor
                  Value {
                    Integral {
                      // \int_S (\vec{r} \times (T_max \vec{n}) ) / ep
                      // with ep = |S| / (2\pi r_avg) (directly accounts for the total torque for the total circumference)
                      [ CompZ [ XYZ[] /\ (T_max[{d a}] * XYZ[]) ] * 2*Pi*thickness/SurfaceArea[] ] ;
                      In Omega ; Jacobian Vol  ; Integration Int; }
                  }
                }
            EndIf
        }
    }
    // Coupled formulation
    { Name MagDyn_coupled; NameOfFormulation MagDyn_coupled;
        Quantity {
            { Name phi; Value{ Local{ [ {dInv h} ] ;
                In Omega_h_OmegaCC_AndBnd; Jacobian Vol; } } }
            { Name h; Value {
                Term { [ {h} ]; In Omega_h; Jacobian Vol; }
                Term { [ nu[{d a}] * {d a} ] ; In MagnAnhyDomain; Jacobian Vol; }
                Term { [ nu[] * {d a} ] ; In MagnLinDomain; Jacobian Vol; }
                }
            }
            { Name b; Value{
                Term { [ mu[{h}]*{h} ]; In Omega_h; Jacobian Vol; }
                Term { [ {d a} ] ; In Omega_a; Jacobian Vol;} } }
            { Name bx; Value{
                Term { [ mu[{h}]*CompX[{h}] ]; In Omega_h; Jacobian Vol; }
                Term { [ CompX[{d a}] ] ; In Omega_a; Jacobian Vol;} } }
            { Name a; Value{ Local{ [ {a} ] ;
                In Omega_a; Jacobian Vol; } } }
            { Name a_bnd; Value{ Local{ [ {a} ] ;
                In BndOmega_ha; Jacobian Sur; } } }
            { Name mur; Value{ Local{ [ 1.0/(nu[{d a}] * mu0) ] ;
                In Omega_a; Jacobian Vol; } } }
            { Name j; Value{
                Local{ [ {d h} ] ; In Omega_h_OmegaC; Jacobian Vol; } } }
            If(Flag_hs == 1)
                { Name js; Value{ Local{ [ {d h} ] ;
                    In OmegaC_stranded; Jacobian Vol; } } }
            Else
                { Name js; Value{ Local{ [ js[] ] ;
                    In OmegaC_stranded; Jacobian Vol; } } }
            EndIf
            { Name e; Value{ Local{ [ rho[{d h}, mu[{h}]*Norm[{h}] ]*{d h} ] ;
                In Omega_h_OmegaC; Jacobian Vol; } } }
            { Name jouleLosses; Value{ Local{ [ rho[{d h}, mu[{h}]*Norm[{h}] ] * {d h} * {d h}] ;
                In Omega_h_OmegaC; Jacobian Vol; } } }
            { Name jz; Value{ Local{ [ CompZ[{d h}] ] ;
                In Omega_h_OmegaC; Jacobian Vol; } } }
            { Name norm_j; Value{ Local{ [ Norm[{d h}] ] ;
                In Omega_h_OmegaC; Jacobian Vol; } } }
            { Name normal_j; Value{ Local{ [ -CompX[{d h}]+CompY[{d h}] ] ;
                In Omega_h_OmegaC; Jacobian Vol; } } }
            { Name normal; Value{ Local{ [ Normal[] ] ;
                In BndOmega_ha; Jacobian Vol; } } }
            If(Axisymmetry == 1)
                { Name m_avg; Value{ Integral{ [ 2*Pi * 0.5 * XYZ[] /\ {d h} / (Pi*SurfaceArea[]*W/2) ] ;
                    In Omega_h_OmegaC; Integration Int; Jacobian Vol; } } } // Jacobian is in "Vol"
                { Name m_avg_y_tesla; Value{ Integral{ [ mu0*2*Pi * 0.5 * Vector[0,1,0] * (XYZ[] /\ {d h}) / (Pi*SurfaceArea[]*W/2) ] ;
                    In Omega_h_OmegaC; Integration Int; Jacobian Vol; } } }
            ElseIf(Dim == 1)
                // TBC...
            ElseIf(Dim == 2)
                { Name m_avg; Value{ Integral{ [ 0.5 * XYZ[] /\ {d h} / (SurfaceArea[]) ] ;
                    In Omega_h_OmegaC; Integration Int; Jacobian Vol; } } }
                { Name m_avg_y_tesla; Value{ Integral{ [ mu0 * 0.5 * Vector[0,1,0] * (XYZ[] /\ {d h}) / (SurfaceArea[]) ] ;
                    In Omega_h_OmegaC; Integration Int; Jacobian Vol; } } }
                { Name m_avg_x_tesla; Value{ Integral{ [ mu0 * 0.5 * Vector[1,0,0] * (XYZ[] /\ {d h}) / (SurfaceArea[]) ] ;
                    In Omega_h_OmegaC; Integration Int; Jacobian Vol; } } }
            ElseIf(Dim == 3)
                { Name m_avg; Value{ Integral{ [ 0.5 * XYZ[] /\ {d h} / GetVolume[] ] ;
                    In Omega_h_OmegaC; Integration Int; Jacobian Vol; } } }
            EndIf
            { Name b_avg; Value{ Integral{ [ 2*Pi*mu[{h}] * {h} / (SurfaceArea[]) ] ;
                In Omega_h_OmegaC; Integration Int; Jacobian Vol; } } }
            { Name hsVal; Value{ Term { [ hsVal[] ]; In Omega; } } }
            { Name bsVal; Value{ Term { [ mu0*hsVal[] ]; In Omega; } } }
            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }
            If(Flag_MB == 1)
                { Name js_value; Value{ Term { [ pulse[] ]; In Omega; } } }
                { Name rotor_angle; Value{ Term { [ 180/Pi*omega*$Time ]; In Omega; } } }
            EndIf
            { Name power;
                Value{
                    Integral{ [ ({d a} - {d a}[1]) / $DTime * nu[{d a}] * ({d a}+{d a}[1])/2 ] ;
                        In MagnAnhyDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [ ({d a} - {d a}[1]) / $DTime * nu[] * ({d a}+{d a}[1])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [ (mu[{h}]*{h} - mu[{h}]*{h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [rho[{d h}, mu[{h}]*Norm[{h}] ]*{d h}*{d h}] ;
                        In Omega_h_OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
            { Name dissPower;
                Value{
                    Integral{ [rho[{d h}, mu[{h}]*Norm[{h}] ]*{d h}*{d h}] ;
                        In OmegaC ; Integration Int ; Jacobian Vol; }
                }
            }
            { Name V;
                Value{
                    Term{ [ {V} ] ; In Cuts;}
                }
            }
            { Name I;
                Value{
                    Term{ [ {I} ] ; In Cuts;}
                }
            }
            { Name dissPowerGlobal;
                Value{
                    Term{ [ {V}*{I} ] ; In Cuts;}
                }
            }
            If(Flag_MB==1)
                { Name torqueMaxwell ;
                  // Torque computation via Maxwell stress tensor (should be in a domain)
                  Value {
                    Integral {
                      // \int_S (\vec{r} \times (T_max \vec{n}) ) / ep
                      // with ep = |S| / (2\pi r_avg) (directly accounts for the total torque for the total circumference)
                      [ CompZ [ XYZ[] /\ (T_max[{d a}] * XYZ[]) ] * 2*Pi*thickness/SurfaceArea[] ] ;
                      In Omega ; Jacobian Vol  ; Integration Int; }
                  }
                }
            EndIf
        }
    }
    // t-a-formulation -> look here to see how things have to be interpreted.
    { Name MagDyn_ta; NameOfFormulation MagDyn_ta;
        Quantity {
            { Name h; Value {
                Term { [ nu[{d a}] * {d a} ] ; In MagnAnhyDomain; Jacobian Vol; }
                Term { [ nu[] * {d a} ] ; In MagnLinDomain; Jacobian Vol; }
                }
            }
            { Name b; Value{
                Term { [ {d a} ] ; In Omega_a; Jacobian Vol;} } }
            { Name by; Value{
                Term { [ CompY[{d a}]*Vector[0,1,0] ] ; In Omega_a; Jacobian Vol;} } }
            { Name a; Value{ Local{ [ {a} ] ;
                In Omega_a_AndBnd; Jacobian Vol; } } }
            // { Name hxn; Value{ Local{ [ Normal[] /\ {h} ] ;
            //    In Bnd; Jacobian Sur; } } }
            { Name compz_a; Value{ Local{ [ CompZ[{a}] ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name normal; Value{ Local{ [ Normal[] ] ;
                In OmegaC; Jacobian Sur; } } }
            { Name mur; Value{ Local{ [ 1.0/(nu[{d a}] * mu0) ] ;
                In OmegaCC; Jacobian Vol; } } }
            // { Name j; Value{ Local{ [ 1./thickness[] * {d t} /\ Normal[] ] ;
            //    In Omega; Jacobian Sur; } } }
             { Name j; Value{ Local{ [ 1./thickness[] * {d t} /\ Normal[] ] ;
                In Omega; Jacobian Sur; } } }
            { Name t; Value{ Local{ [ 1./thickness[] * {t} * Normal[] ] ;
                In OmegaC; Jacobian Sur; } } }
            { Name tNorm; Value{ Local{ [ 1./thickness[] * {t} ] ;
                In OmegaC; Jacobian Sur; } } }
            { Name e; Value{ Local{ [ 1./thickness[] * rho[ 1./thickness[] * {d t} /\ Normal[], Norm[{d a}] ]*{d t} /\ Normal[] ] ;
                In OmegaC; Jacobian Sur; } } }
            { Name jouleLosses; Value{ Local{ [ (1./thickness[] * {d t} /\ Normal[]) * (1./thickness[] * rho[ 1./thickness[] * {d t} /\ Normal[], Norm[{d a}] ]*{d t} /\ Normal[]) ] ;
                In OmegaC; Jacobian Sur; } } }
            { Name jz; Value{ Local{ [ 1./thickness[] * CompZ[{d t} /\ Normal[]] ] ;
                In OmegaC; Jacobian Sur; } } }
            { Name norm_j; Value{ Local{ [ 1./thickness[] * Norm[{d t} /\ Normal[]] ] ;
                In OmegaC; Jacobian Sur; } } }
            { Name m_avg; Value{ Integral{ [ 0 ] ;
                In OmegaC; Integration Int; Jacobian Sur; } } } // TO DO
            { Name b_avg; Value{ Integral{ [ 0 / (SurfaceArea[]) ] ;
                In OmegaC; Integration Int; Jacobian Sur; } } } // TO DO
            { Name hsVal; Value{ Term { [ hsVal[] ]; In Omega; } } }
            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }
            { Name power;
                Value{
                    Integral{ [ ({d a} - {d a}[1]) / $DTime * nu[{d a}] * ({d a}+{d a}[1])/2 ] ;
                        In MagnAnhyDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [ ({d a} - {d a}[1]) / $DTime * nu[] * ({d a}+{d a}[1])/2 ] ;
                        In Air ; Integration Int ; Jacobian Vol; }
                    Integral{ [ thickness[]*({d a} - {d a}[1]) / $DTime * nu[] * {d a} ] ;
                        In OmegaC ; Integration Int ; Jacobian Sur; }
                    //Integral{ [  1./thickness[] * (mu[{t}]*{t} - mu[{t}]*{t}[1]) / $DTime * {t} ] ;
                    //    In OmegaC ; Integration Int ; Jacobian Sur; } // Neglected.
                    Integral{ [ 1./thickness[] * rho[1./thickness[] * {d t} /\ Normal[], Norm[{d a}] ]*{d t}*{d t}] ;
                        In OmegaC ; Integration Int ; Jacobian Sur; }
                }
            }
            { Name dissPower;
                Value{
                    Integral{ [ 1./thickness[] * rho[ 1./thickness[] * {d t} /\ Normal[], Norm[{d a}] ]*{d t}*{d t}] ;
                        In OmegaC ; Integration Int ; Jacobian Sur; }
                }
            }
            { Name dissPowerCut;
                Value{
                    Integral{ [ (CompZ[XYZ[]]>0.005 && CompZ[XYZ[]]<0.023 ) * 1./thickness[] * rho[ 1./thickness[] * {d t} /\ Normal[], Norm[{d a}] ]*{d t}*{d t}] ;
                        In OmegaC ; Integration Int ; Jacobian Sur; }
                }
            }
            { Name V;
                Value{
                    Term{ [ {V} ] ; In PositiveEdges;}
                }
            }
            { Name I;
                Value{
                    Term{ [ {T} ] ; In PositiveEdges;}
                }
            }
            { Name dissPowerGlobal;
                Value{
                    Term{ [ thickness[] * {V}*{T} ] ; In PositiveEdges;}
                }
            }
        }
    }
    // Thin-shell model (to be completed and checked, e.g. for power) (Bruno de Sousa Alves)
    { Name MagDyn_hphits; NameOfFormulation MagDyn_hphits;
        Quantity {
            { Name phi; Value{ Local{ [ {dInv h} ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name h; Value{ Local{ [ {h} ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name b; Value{ Local{ [ mu[]*{h} ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name norm_b; Value{ Term{ [ Norm[{h}] * mu[] ] ;
                In OmegaCC; Jacobian Vol; } } }
            { Name dtb; Value{ Local{ [ mu[]* Dt[{h}]  ] ;
                In OmegaCC; Jacobian Vol; } } }

            { Name time; Value{ Term { [ $Time ]; In Omega; } } }
            { Name time_ms; Value{ Term { [ 1000*$Time ]; In Omega; } } }

            { Name I ; Value { Term { [ {I} ] ;
                In Cuts ; } } }
            { Name V ; Value { Term { [ {V} ] ;
                In Cuts ; } } }
            { Name Z ; Value { Term { [ {V} / {I} ] ;
                In Cuts ; } } }
            { Name dissPowerGlobal;
                Value { Term{ [ {V}*{I} ] ; In Cuts; } } }

            For i In {0:N_ele+1+1}
                { Name hi~{i}; Value{ Local{ [{hi~{i}}  ] ; // Magnetic field tangential component in each intermediary surface of the virtual representation
                In GammaS~{(i<N_ele+1)? 0:1}; Jacobian Sur; } } }
            EndFor

            For i In {1:N_ele+1-1}
                { Name norm_jijc~{i}; Value{ Local{ [Norm[{hi~{i}}-{hi~{i+1}}] *1/Delta/jc ] ; // Norm of the relative current density in each virtual element
                In GammaS~{(i<N_ele+1)? 0:1}; Jacobian Sur; } } }

                { Name jijc~{i}; Value{ Local{ [ {hi~{i}}*1/Delta/jc /\ -Normal[] -{hi~{i+1}}*1/Delta/jc /\ -Normal[]   ] ; // Current density vector in each virtual element
                In GammaS~{(i<N_ele+1)? 0:1}; Jacobian Sur; } } }

                { Name norm_ji~{i}; Value{ Local{ [Norm[{hi~{i}}-{hi~{i+1}}] *1/Delta ] ; // Norm of the relative current density in each virtual element
                In GammaS~{(i<N_ele+1)? 0:1}; Jacobian Sur; } } }

                { Name ji~{i}; Value{ Local{ [ {hi~{i}}*1/Delta /\ -Normal[] - {hi~{i+1}}*1/Delta /\ -Normal[]   ] ; // Current density vector in each virtual element
                In GammaS~{(i<N_ele+1)? 0:1}; Jacobian Sur; } } }
            EndFor
            // TO CHECK: not general if we add new domains!
            { Name power; // (h+h[1])/2 instead of h -> to avoid a constant sign error accumulation
                Value{
                    Integral{ [ (mu[{h}]*{h} - mu[{h}[1]]*{h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                        In MagnAnhyDomain ; Integration Int ; Jacobian Vol; }
                    Integral{ [ mu[] * ({h} - {h}[1]) / $DTime * ({h}+{h}[1])/2 ] ;
                        In MagnLinDomain ; Integration Int ; Jacobian Vol; }
                    For i In {0:N_ele+1}
                        Integral {
                            [ rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i}} * 1/Delta * {hi~{i}} ] ;
                                In GammaS~{(i<N_ele+1)? 0:1}  ; Jacobian Sur ; Integration Int ; }
                        Integral {
                            [ - rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i}} * 1/Delta * {hi~{i+1}} ] ;
                                In GammaS~{(i<N_ele+1)? 0:1}  ; Jacobian Sur ; Integration Int ; }
                        Integral {
                            [ - rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i+1}} * 1/Delta * {hi~{i}} ] ;
                                In GammaS~{(i<N_ele+1)? 0:1}  ; Jacobian Sur ; Integration Int ; }
                        Integral {
                            [ rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i+1}} * 1/Delta * {hi~{i+1}} ] ;
                                In GammaS~{(i<N_ele+1)? 0:1}  ; Jacobian Sur ; Integration Int ; }
                    EndFor
                }
            }

            { Name dissPower ; // Instantaneous AC losses in the tape
                Value {
                    For i In {0:N_ele+1}
                        Integral {
                            [ rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i}} * 1/Delta * {hi~{i}} ] ;
                                In GammaS~{(i<N_ele+1)? 0:1}  ; Jacobian Sur ; Integration Int ; }
                        Integral {
                            [ - rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i}} * 1/Delta * {hi~{i+1}} ] ;
                                In GammaS~{(i<N_ele+1)? 0:1}  ; Jacobian Sur ; Integration Int ; }
                        Integral {
                            [ - rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i+1}} * 1/Delta * {hi~{i}} ] ;
                                In GammaS~{(i<N_ele+1)? 0:1}  ; Jacobian Sur ; Integration Int ; }
                        Integral {
                            [ rho_powerTS[{hi~{i}},{hi~{i+1}}] * {hi~{i+1}} * 1/Delta * {hi~{i+1}} ] ;
                                In GammaS~{(i<N_ele+1)? 0:1}  ; Jacobian Sur ; Integration Int ; }
                    EndFor
                }
            }
        }
    }
}
