// ----------------------------------------------------------------------------
// -------------------------- GROUPS ------------------------------------------
// ----------------------------------------------------------------------------
// Groups associated with function spaces
Group{
    // Domains for the different formulations
    If(formulation == h_formulation || formulation == h_formulation+1 || formulation == h_formulation+2 || formulation == h_phi_ts_formulation)
        Omega_h = Region[{Omega}];
        Omega_h_AndBnd = Region[{Omega,GammaAll}];
        Omega_h_OmegaC = Region[{OmegaC}];
        Omega_h_OmegaC_AndBnd = Region[{OmegaC, BndOmegaC}];
        Omega_h_OmegaCC = Region[{OmegaCC}];
        If(Flag_MB==1)
            Omega_h_OmegaCC_AndBnd = Region[{OmegaCC, BndOmegaC, Rotor_Bnd_MBaux}];
        Else
            Omega_h_OmegaCC_AndBnd = Region[{OmegaCC, BndOmegaC, GammaS}];
        EndIf
        Omega_a  = Region[{}];
        Omega_a_AndBnd = Region[{}];
        Omega_a_OmegaCC = Region[{}];
        BndOmega_ha = Region[{}];
    ElseIf(formulation == a_formulation)
        Omega_h = Region[{}];
        Omega_h_AndBnd = Region[{}];
        Omega_h_OmegaC = Region[{}];
        Omega_h_OmegaC_AndBnd = Region[{}];
        Omega_h_OmegaCC = Region[{}];
        Omega_h_OmegaCC_AndBnd = Region[{}];
        Omega_a  = Region[{Omega}];
        If(Flag_MB==1)
            Omega_a_AndBnd  = Region[{Omega, GammaAll, BndOmegaC, Rotor_Bnd_MBaux}];
        Else
            Omega_a_AndBnd  = Region[{Omega, GammaAll, BndOmegaC}];
        EndIf
        Omega_a_OmegaCC = Region[{OmegaCC}];
        Omega_a_OmegaCC_AndBnd = Region[{OmegaCC, BndOmegaC}];
        BndOmega_ha = Region[{}];
    ElseIf(formulation == coupled_formulation)
        If(automatic_ha_domains == 1)
            Omega_h = Region[{OmegaC}];
            Omega_h_AndBnd = Region[{OmegaC,BndOmegaC}];
            Omega_h_OmegaC = Region[{OmegaC}];
            Omega_h_OmegaC_AndBnd = Region[{OmegaC, BndOmegaC}];
            Omega_h_OmegaCC = Region[{}];
            Omega_h_OmegaCC_AndBnd = Region[{BndOmegaC}];
            Omega_a  = Region[{OmegaCC}];
            If(Flag_MB==1)
                Omega_a_AndBnd  = Region[{OmegaCC, GammaAll, BndOmegaC, Rotor_Bnd_MBaux}];
            Else
                Omega_a_AndBnd  = Region[{OmegaCC, GammaAll, BndOmegaC}];
            EndIf
            Omega_a_OmegaCC = Region[{OmegaCC}];
            BndOmega_ha = Region[{BndOmegaC}];
        EndIf
    ElseIf(formulation == ta_formulation)
        Omega_h = Region[{OmegaC}];
        Omega_h_OmegaC = Region[{OmegaC}];
        Omega_h_AndBnd = Region[{Omega_h_OmegaC}];
        Omega_h_OmegaC_AndBnd = Region[{OmegaC, LateralEdges}];
        Omega_h_OmegaCC = Region[{}];
        Omega_h_OmegaCC_AndBnd = Region[{}];
        Omega_a  = Region[{OmegaCC}];
        Omega_a_AndBnd  = Region[{Omega_a, OmegaC, GammaAll, PositiveEdges}];
        Omega_a_OmegaCC = Region[{OmegaCC}];
        BndOmega_ha = Region[{OmegaC}];
    EndIf
    TransitionLayerAndBndOmegaC = ElementsOf[BndOmegaC_side, OnOneSideOf Cuts];
}
Function{
    // Maxwell's tensor
    T_max[] = ( SquDyadicProduct[$1] - SquNorm[$1] * TensorDiag[0.5, 0.5, 0.5] ) / mu0 ;
}

// ----------------------------------------------------------------------------
// -------------------------- JACOBIAN ----------------------------------------
// ----------------------------------------------------------------------------
// Jacobian-type for the transformation into isoparameteric elements
Jacobian {
    // For volume integration (Dim N)
    { Name Vol ;
        Case {
            If(Axisymmetry == 0)
                // Classical transformation Jacobian
                {Region All ; Jacobian Vol ;}
            Else
                // Axisymmetric problems
                //  Simple Jacobian, well suited to Edge basis function
                {Region Omega_h ; Jacobian VolAxi ;}
                //  Second-type, better suited to PerpendicularEdge basis functions
                {Region Omega_a ; Jacobian VolAxiSqu ;}
            EndIf
        }
    }
    // For surface integration (Dim N-1)
    { Name Sur ;
        Case {
            If(Axisymmetry == 0)
                { Region All ; Jacobian Sur ; }
            Else
                { Region All ; Jacobian SurAxi ; }
            EndIf
        }
    }
}

// ----------------------------------------------------------------------------
// --------------------------- INTEGRATION ------------------------------------
// ----------------------------------------------------------------------------
// Type of integration and number of quadrature points for each element type
If(Dim == 1 || Dim == 2)
    Integration {
        { Name Int ;
            Case {
                { Type Gauss ;
                    Case {
                        { GeoElement Point ; NumberOfPoints 1 ; }
                        { GeoElement Line ; NumberOfPoints 3 ; }
                        { GeoElement Line2 ; NumberOfPoints 4 ; } // Second-order element
                        { GeoElement Triangle ; NumberOfPoints 3 ; } // TO BE FIXED HERE! 12 previously
                        { GeoElement Triangle2 ; NumberOfPoints 12 ; }
                        { GeoElement Quadrangle ; NumberOfPoints 4 ; }
                        { GeoElement Quadrangle2 ; NumberOfPoints 7 ; } // Second-order element
                    }
                }
            }
        }
    }
Else
    Integration {
        { Name Int ;
            Case {
                { Type Gauss ;
                    Case {
                        { GeoElement Point ; NumberOfPoints 1 ; }
                        { GeoElement Line ; NumberOfPoints 3 ; }
                        { GeoElement Line2 ; NumberOfPoints 4 ; } // Second-order element
                        { GeoElement Triangle ; NumberOfPoints 12 ; } // To ensure sufficent nb of points with hierarchical elements in coupled formulations (to be optimized)
                        { GeoElement Triangle2 ; NumberOfPoints 12 ; }
                        { GeoElement Quadrangle ; NumberOfPoints 4 ; }
                        { GeoElement Quadrangle2 ; NumberOfPoints 4 ; } // Second-order element
                         { GeoElement Tetrahedron ; NumberOfPoints  5 ; }
                        // { GeoElement Tetrahedron ; NumberOfPoints  15 ; }
                        { GeoElement Tetrahedron2 ; NumberOfPoints  5 ; } // Second-order element
                        { GeoElement Pyramid ; NumberOfPoints  8 ; }
                        { GeoElement Prism ; NumberOfPoints  9 ; }
                        { GeoElement Hexahedron ; NumberOfPoints  6 ; }
                    }
                }
            }
        }
        { Name Int_0 ;
            Case {
                { Type Gauss ;
                    Case {
                        { GeoElement Point ; NumberOfPoints 1 ; }
                        { GeoElement Line ; NumberOfPoints 1 ; }
                        { GeoElement Triangle ; NumberOfPoints 1 ; }
                        { GeoElement Quadrangle ; NumberOfPoints 1 ; }
                        { GeoElement Tetrahedron ; NumberOfPoints  1 ; }
                        { GeoElement Pyramid ; NumberOfPoints  1 ; }
                        { GeoElement Prism ; NumberOfPoints  1 ; }
                        { GeoElement Hexahedron ; NumberOfPoints  6 ; }
                    }
                }
            }
        }
        { Name Int_1 ;
            Case {
                { Type Gauss ;
                    Case {
                        { GeoElement Point ; NumberOfPoints 1 ; }
                        { GeoElement Line ; NumberOfPoints 2 ; }
                        { GeoElement Triangle ; NumberOfPoints 3 ; }
                        { GeoElement Quadrangle ; NumberOfPoints 4 ; }
                        { GeoElement Tetrahedron ; NumberOfPoints  4 ; }
                        { GeoElement Pyramid ; NumberOfPoints  8 ; }
                        { GeoElement Prism ; NumberOfPoints  9 ; }
                        { GeoElement Hexahedron ; NumberOfPoints  6 ; }
                    }
                }
            }
        }
    }
EndIf
