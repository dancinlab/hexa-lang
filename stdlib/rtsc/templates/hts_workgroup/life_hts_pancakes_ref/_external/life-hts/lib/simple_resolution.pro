// simplified version of the "resolution.pro" file
// using built-in GetDP operations for faster resolution

Function{
    // Output directory name (.txt only, .pos are not put there)
    DefineConstant [resDirectory = StrCat["../",name,"/res/"]];
    DefineConstant [outputDirectory = StrCat[resDirectory,testname]];
    DefineConstant [RobustLinearSolver = Str["-ksp_type preonly -pc_type lu -pc_factor_mat_solver_type mumps -mat_mumps_icntl_14 800"]];
    //DefineConstant [RobustLinearSolver = Str["-ksp_type preonly -pc_type lu -pc_factor_mat_solver_type superlu_dist"]];
    DefineConstant [FastLinearSolver = Str["-ksp_type gmres -ksp_rtol 1e-12 -ksp_atol 1e-12 -ksp_max_it 50 -pc_type asm -sub_pc_type lu -sub_pc_factor_mat_solver_type mumps -mat_mumps_icntl_14 800 -sub_ksp_type preonly -pc_asm_overlap 1"]];
}

// ----------------------------------------------------------------------------
// --------------------------- RESOLUTION -------------------------------------
// ----------------------------------------------------------------------------
Resolution {
    { Name MagDyn;
        System { { Name A; NameOfFormulation MagDyn_htot; } }
        Operation {
            // Create directory to store result files
            CreateDirectory[resDirectory];
            CreateDirectory[outputDirectory]; // For .txt ouput files
            // init solutions
            InitSolution[A];
            SaveSolution[A];
            // Count the number of solved linear systems
            Evaluate[ $syscount = 0 ];
            SetExtrapolationOrder[1]; // Set the extrapolation order to one for the initial iterate at each time step
            If(Flag_try_ASM_before_MUMPS)
                SetGlobalSolverOptions[FastLinearSolver]; // Use ASM before MUMPS
            Else
                SetGlobalSolverOptions[RobustLinearSolver]; // Use MUMPS directly
            EndIf
            TimeLoopAdaptive[timeStart,
                timeFinalSimu,
                dt,
                dt/50000,
                dt_max,
                "Euler", // "Euler" for Implicit Euler, "Gear_2" for backward differentiation formula of order 2
                List[controlTimeInstants],
                System{
                    {
                        A,
                        0.02, // relative tolerance (this tolerance can be chosen to be weaker than the nonlinear one)
                        10000.0, // absolute tolerance (this tolerance can be chosen to be weaker than the nonlinear one)
                        LinfNorm
                    }
                }

            ]{
                // This first part is executed for each time step
                // Nonlinear solver starts +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                IterativeLoopN[
                    iter_max,
                    relaxation_factor,
                    System{
                        {
                            A,
                            tol_rel,
                            tol_abs,
                            Residual MeanL2Norm
                        }
                    }
                ]{
                    GenerateJac[A];
                    SolveJac[A];
                    Evaluate[ $syscount = $syscount + 1 ];
                }

                // Check if the last linear solution has diverged (e.g. is NaN)
                Test[$KSPConvergedReason < 0]{
                  Print[{$KSPConvergedReason}, Format "Critical: linear solver diverged (reason = %g): removing solution from the solution vector"];
                  // remove solution from solution vector
                  RemoveLastSolution[A];
                  If(Flag_try_ASM_before_MUMPS)
                    SetGlobalSolverOptions[RobustLinearSolver]; // switch to robust (direct) linear solver
                  EndIf
                }
                // Nonlinear solver ends +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

            }{
                // This second part is executed only if the time step is accepted
                SaveSolution[A];
                PostOperation[MagDyn_energy];
                Print[{$Time, $indicDissSuper}, Format "%g %g", File StrCat[outputDirectory, "/power.txt"]];

                If(Flag_try_ASM_before_MUMPS)
                    // switch back to fast linear solver
                    SetGlobalSolverOptions[FastLinearSolver];
                EndIf
            } // ----- End time loop -----
            // Print information about the resolution and the nonlinear iterations
            Print[{$syscount}, Format "Total number of linear systems solved: %g"];
            //Print[A];
        }
    }
}

// ----------------------------------------------------------------------------
// --------------------------- POST-OPERATION ---------------------------------
// ----------------------------------------------------------------------------
// Operations useful for convergence criterion
PostOperation {
    // Extracting energetic quantities
    { Name MagDyn_energy ; NameOfPostProcessing MagDyn_htot ; LastTimeStepOnly 1 ;
        Operation{
            Print[ dissPower[NonLinOmegaC], OnGlobal, Format Table, StoreInVariable $indicDissSuper, File > "res/dummy.txt" ];
            Print[ dissPower[LinOmegaC], OnGlobal, Format Table, StoreInVariable $indicDissLin, File > "res/dummy.txt" ];
        }
    }
}
