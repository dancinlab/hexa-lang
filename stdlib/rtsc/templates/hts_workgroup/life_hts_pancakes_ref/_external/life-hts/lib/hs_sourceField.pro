Group{
    TransitionLayerAndBndOmegaC_stranded = ElementsOf[BndOmegaC_stranded_side, OnOneSideOf Cuts_stranded];
    Omega_h_OmegaC_stranded_AndBnd = Region[ {OmegaC_stranded, BndOmegaC_stranded} ];
    Omega_h_noStranded = Region[ {Omega_h} ];
    Omega_h_noStranded -= Region[ {OmegaC_stranded} ];
}
Constraint {
    { Name GaugeCondition_hs ; Type Assign ;
        Case {
            { Region OmegaC_stranded ; SubRegion BndOmegaC_stranded ; Value 0. ; }
        }
    }
    { Name Current_hs ; Type Assign ;
        Case {
            { Region Cuts_stranded; Value 1.0;}
        }
    }
}
FunctionSpace {
    // Function space for source current density in stranded conductor
    { Name hs_space; Type Form1;
        BasisFunction {
            { Name psie; NameOfCoef he; Function BF_Edge;
                Support OmegaC_stranded; Entity EdgesOf[All, Not BndOmegaC_stranded]; }
            If(Flag_cohomology == 0)
                { Name ci; NameOfCoef Ii; Function BF_GradGroupOfNodes;
                    Support ElementsOf[Omega_h_noStranded, OnPositiveSideOf Cuts_stranded];
                    Entity GroupsOfNodesOf[Cuts_stranded]; }
                { Name ci; NameOfCoef Ii2; Function BF_GroupOfEdges;
                    Support Omega_h_OmegaC_stranded_AndBnd;
                    Entity GroupsOfEdgesOf[Cuts_stranded, InSupport TransitionLayerAndBndOmegaC_stranded] ; }
            Else
                { Name sc; NameOfCoef Ii; Function BF_GroupOfEdges;
                    Support Omega_h; Entity GroupsOfEdgesOf[Cuts_stranded]; }
            EndIf
        }
        Constraint {
            { NameOfCoef he; EntityType EdgesOfTreeIn; EntitySubType StartingOn;
                NameOfConstraint GaugeCondition_hs; }
            { NameOfCoef Ii ; EntityType GroupsOfEdgesOf ; NameOfConstraint Current_hs ; }
            If(Flag_cohomology == 0)
                { NameOfCoef Ii2 ; EntityType GroupsOfEdgesOf ; NameOfConstraint Current_hs ; }
            EndIf
        }
    }
}
Formulation{
    // Pre-formulation for source field in h-formulation
    { Name js_to_hs~{Nb_source_domain} ; Type FemEquation ;
        Quantity {
            { Name hs ; Type Local  ; NameOfSpace hs_space ; }
        }
        Equation {
            Galerkin { [  Dof{d hs}, {d hs} ] ;
                In OmegaC_stranded ; Jacobian Vol ; Integration Int ; }
            Galerkin { [ - js0[], {d hs} ] ;
                In OmegaC_stranded ; Jacobian Vol ; Integration Int ; }
        }
    }
}

Resolution {
  { Name js_to_hs~{Nb_source_domain} ;
    System {
      { Name Sys_Mag ; NameOfFormulation js_to_hs~{Nb_source_domain} ; }
    }
    Operation {
      Generate Sys_Mag ; Solve Sys_Mag ;
      If (Flag_save_hs == 1) SaveSolution Sys_Mag ; EndIf
    }
  }
}

// To check the source field
PostProcessing {
  { Name js_to_hs~{Nb_source_domain} ; NameOfFormulation js_to_hs~{Nb_source_domain} ;
    PostQuantity {
      { Name hs  ; Value { Term { [ {hs} ] ; Jacobian Vol ;
        In Omega ; } } }
      { Name js  ; Value { Term { [ {d hs} ] ; Jacobian Vol ;
        In OmegaC_stranded ; } } }
      { Name js0 ; Value { Term { [ js0[] ] ;
        In OmegaC_stranded ; Jacobian Vol ; } } }
      /*{ Name jsx ; Value { Term { [ CompX[{d hs}] ] ;
        In Domain_SourceField_Mag~{iInd} ; Jacobian Vol ; } } }
      { Name jsy ; Value { Term { [ CompY[{d hs}] ] ;
        In Domain_SourceField_Mag~{iInd} ; Jacobian Vol ; } } }
      { Name jsz ; Value { Term { [ CompZ[{d hs}] ] ;
        In Domain_SourceField_Mag~{iInd} ; Jacobian Vol ; } } }*/
    }
  }
}
