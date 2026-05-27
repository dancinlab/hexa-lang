// ---- Formulation definitions (dummy values) ----
DefineConstant [formulation];

nbConductors = 1; //number conductors, useful if multiple conductors for imposing global conditions in h-phi formulations. This is updated in each model .pro file.

N_ele = 1; // Default number of layers for the thin-shell formulation
Delta = 1; // default thickness virtual element thin-shell. updated in smsts model .pro file

Group{
    // Regions that must be consistently completed (or left empty if they do not apply)
    DefineGroup[OmegaC, OmegaCC, Omega, BndOmegaC];
    DefineGroup[Gamma_e, Gamma_h, GammaAll];
    DefineGroup[MagnLinDomain];
    DefineGroup[LinOmegaC, NonLinOmegaC];

    DefineGroup[Cuts];
    DefineGroup[GammaTS, GammaTS_1, GammaTS_0]; // For thin-shell model

    DefineGroup [Air, Super];

}

Function{
    // Functions that will be called in some post-operation (define them or not)
    DefineFunction [I, js];
}
