Group{
    If(formulation == 7) // smsts-ta
        Omega_h = Region[{OmegaC}];
        Omega_h_OmegaC = Region[{OmegaC}];
        Omega_h_AndBnd = Region[{Omega_h_OmegaC}];
        Omega_h_OmegaC_AndBnd = Region[{OmegaC, TS_LateralEdges}];
        Omega_h_OmegaCC = Region[{}];
        Omega_h_OmegaCC_AndBnd = Region[{}];
        Omega_a  = Region[{OmegaCC}]; // huge bug here because was set to air and not OmegaCC
        Omega_a_AndBnd  = Region[{Omega_a, OmegaC, GammaAll, TS_EdgeRight}];
        Omega_a_OmegaCC = Region[{OmegaCC}];
        BndOmega_ha = Region[{OmegaC}];
    Else // h-based
        Omega_h = Region[{Omega}];
        Omega_h_AndBnd = Region[{Omega,GammaAll}];
        Omega_h_OmegaC = Region[{OmegaC}];
        Omega_h_OmegaC_AndBnd = Region[{OmegaC, BndOmegaC}];
        Omega_h_OmegaCC = Region[{OmegaCC}];
        Omega_h_OmegaCC_AndBnd = Region[{OmegaCC, BndOmegaC, GammaTS}];
        Omega_a  = Region[{}];
        Omega_a_AndBnd = Region[{}];
        Omega_a_OmegaCC = Region[{}];
        BndOmega_ha = Region[{}];
    EndIf
}

// ----------------------------------------------------------------------------
// -------------------------- JACOBIAN ----------------------------------------
// ----------------------------------------------------------------------------
// Jacobian-type for the transformation into isoparameteric elements
Jacobian {
    // For volume integration (Dim N)
    { Name Vol ;
        Case {
            // Classical transformation Jacobian
            {Region All ; Jacobian Vol ;}
        }
    }
    // For surface integration (Dim N-1)
    { Name Sur ;
        Case {
            { Region All ; Jacobian Sur ; }
        }
    }
}

// ----------------------------------------------------------------------------
// --------------------------- INTEGRATION ------------------------------------
// ----------------------------------------------------------------------------
// Type of integration and number of quadrature points for each element type
Integration {
    { Name Int ;
        Case {
            { Type Gauss ;
                Case {
                    { GeoElement Point ; NumberOfPoints 1 ; }
                    { GeoElement Line ; NumberOfPoints 3 ; }
                    { GeoElement Line2 ; NumberOfPoints 4 ; } 
                    { GeoElement Triangle ; NumberOfPoints 3 ; }
                    { GeoElement Triangle2 ; NumberOfPoints 12 ; }
                    { GeoElement Quadrangle ; NumberOfPoints 7 ; }
                    { GeoElement Quadrangle2 ; NumberOfPoints 7 ; }
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
}