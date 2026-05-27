Function{
    // Output directory name (.txt only, .pos are not put there)
    DefineConstant [resDirectory = StrCat["../",name,"res/"]];
    DefineConstant [outputDirectory = StrCat[resDirectory,testname]];
    // Filenames - On domains
    DefineConstant [infoResidualFile    = StrCat[outputDirectory,"/residual.txt"]];
    DefineConstant [outputPower         = StrCat[outputDirectory,"/power.txt"]];
    // power written in different files
    For i In {1:nbConductors}
        If(formulation == 3 || formulation == 6 || formulation == 7) //smsts
            DefineConstant [outputPowerCond~{i} = StrCat[outputDirectory,Sprintf["/power_ts_%g.txt",i]]];
        Else
            DefineConstant [outputPowerCond~{i} = StrCat[outputDirectory,Sprintf["/power_cond_%g.txt",i]]];
        EndIf
    EndFor

    If(formulation == 3 || formulation == 6 || formulation == 7) // smsts
        For i In {1:nb_eff_source_domains}
            DefineConstant [outputPowerSource~{i} = StrCat[outputDirectory,Sprintf["/power_source_%g.txt",i]]];
        EndFor
    EndIf
    // PARAMETERS POTENTIALLY TO BE MODIFIED GIVEN PROBLEM
    DefineConstant [RobustLinearSolver = Str["-ksp_type preonly -pc_type lu -pc_factor_mat_solver_type mumps -mat_mumps_icntl_14 800"]];
    DefineConstant [FastLinearSolver = Str["-ksp_type gmres -ksp_rtol 1e-12 -ksp_atol 1e-12 -ksp_max_it 250 -pc_type asm -sub_pc_type lu -sub_pc_factor_mat_solver_type mumps -mat_mumps_icntl_14 800 -sub_ksp_type preonly -pc_asm_overlap 1"]];
}

Resolution {
    { Name MagDyn;
        System {
            If(formulation == 0 || formulation == 4) // h-phi-ref or h-phi-hom
                {Name A; NameOfFormulation MagDyn_hphi;}
            ElseIf(formulation == 1 || formulation == 5) // full-h-ref or full-h-hom
                {Name A; NameOfFormulation MagDyn_hfull;}
            ElseIf(formulation == 2) // FW
                {Name A; NameOfFormulation h_2D_fw;}
            ElseIf(formulation == 3 || formulation == 6) // SMSTS or SMSTS-KO
                {Name A; NameOfFormulation MagDyn_hphits_monolithic;}
            ElseIf(formulation == 7) // smsts-ta
                {Name A; NameOfFormulation MagDyn_ta_monolithic;}
            EndIf
        }
        Operation {
            // Create directory to store result files
            CreateDirectory[resDirectory];
            CreateDirectory[outputDirectory]; // For .txt ouput files
            DeleteFile[outputPower]; // Start from a new file
            DeleteFile[infoResidualFile]; // Start from a new file
            For i In {1:nbConductors}
                DeleteFile[outputPowerCond~{i}]; // Start from a new file
            EndFor
            If(formulation == 3 || formulation == 6 || formulation == 7) // smsts
                For i In {1:nb_eff_source_domains}
                    DeleteFile[outputPowerSource~{i}];
                EndFor
            EndIf
            // init solutions
            InitSolution[A];
            SaveSolution[A];
            // Count the number of solved linear systems
            Evaluate[ $syscount = 0 ];
            Evaluate[ $elapsedCTI = 0 ];
            If(Flag_WallTime)
                Evaluate[ $WallTime = 0 ];
                Evaluate[ $WallTimeSolve = 0 ];
                Evaluate[ $WallTimeGenerate = 0 ];
                Evaluate[ $WallTimePostPro = 0 ];
            EndIf
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
                "Euler",
                List[controlTimeInstants],
                System{
                    {
                        A,
                        (formulation == 2 || formulation == 3 || formulation == 6 || formulation == 7)? (formulation == 7 ? 800 : 200) : 0.1, // relative tolerance (this tolerance can be chosen to be weaker than the nonlinear one)
                        (formulation == 2 || formulation == 3 || formulation == 6 || formulation == 7) ? 1000000 : 100, // absolute tolerance (this tolerance can be chosen to be weaker than the nonlinear one)
                        LinfNorm
                    }
                }

            ]{
                // This first part is executed for each time step
                // Nonlinear solver starts +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                IterativeLoopN[
                    iter_max,
                    1, // no relaxation
                    System{
                        {
                            A,
                            tol_rel,
                            tol_abs,
                            Residual MeanL2Norm
                        }
                    }
                ]{
                    If(Flag_WallTime == 1)
                        Evaluate[ $start = GetWallClockTime[]];
                        GenerateJac[A];
                        Evaluate[ $end = GetWallClockTime[]];
                        Evaluate[ $WallTimeGenerate = $WallTimeGenerate + $end - $start];
                        Evaluate[ $start = GetWallClockTime[]];
                        SolveJac[A];
                        Evaluate[ $end = GetWallClockTime[]];
                        Evaluate[ $WallTimeSolve = $WallTimeSolve + $end - $start];
                    Else
                        GenerateJac[A];
                        SolveJac[A];
                    EndIf
                    Evaluate[ $syscount = $syscount + 1 ];
                    If(check_power_conv)
                        If(Flag_WallTime == 1)
                            Evaluate[ $start = GetWallClockTime[]];
                            PostOperation[MagDyn_energy_full];
                            Print[{$Time, $indicAir, $indicDissSuper},
                                Format "%g %14.12e %14.12e", File infoResidualFile];
                            Evaluate[ $end = GetWallClockTime[]];
                            Evaluate[ $WallTimePostPro = $WallTimePostPro + $end - $start];
                        Else
                            PostOperation[MagDyn_energy_full];
                            Print[{$Time, $indicAir, $indicDissSuper},
                                Format "%g %14.12e %14.12e", File infoResidualFile];
                        EndIf
                    EndIf
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
                If(Flag_WallTime == 1)
                    Evaluate[ $start = GetWallClockTime[]];
                    PostOperation[MagDyn_energy];
                    If(formulation == 3 || formulation == 6 || formulation == 7)
                        PostOperation[detailedPower];
                        Test[GetRank[] == 0]{
                            // only the root process executes the Python code
                            If(formulation == 3)
                                SystemCommand[StrCat["python3 ../pancakes_smsts/loss_interpolation.py ", PythonTapeIDs]];
                            ElseIf(formulation == 6)
                                SystemCommand[StrCat["python3 ../pancakes_smsts_ko/loss_interpolation.py ", PythonTapeIDs]];
                            Else
                                SystemCommand[StrCat["python3 ../pancakes_smsts_ta/loss_interpolation.py ", PythonTapeIDs]];
                            EndIf
                        }
                        {
                        // other processes just wait
                        }
                    EndIf
                    Print[{$Time, $indicDissSuper}, Format "%g %14.12e", File outputPower];
                    Print[{$Time}, Format "Time %g saved."];
                    Evaluate[ $end = GetWallClockTime[]];
                    Evaluate[ $WallTimePostPro = $WallTimePostPro + $end - $start];
                Else
                    PostOperation[MagDyn_energy];
                    If(formulation == 3 || formulation == 6 || formulation == 7)
                        PostOperation[detailedPower];
                        Test[GetRank[] == 0]{
                            // only the root process executes the Python code
                            If(formulation == 3)
                                SystemCommand[StrCat["python3 ../pancakes_smsts/loss_interpolation.py ", PythonTapeIDs]];
                            ElseIf(formulation == 6)
                                SystemCommand[StrCat["python3 ../pancakes_smsts_ko/loss_interpolation.py ", PythonTapeIDs]];
                            Else
                                SystemCommand[StrCat["python3 ../pancakes_smsts_ta/loss_interpolation.py ", PythonTapeIDs]];
                            EndIf
                        }
                        {
                        // other processes just wait
                        }
                    EndIf
                    Print[{$Time, $indicDissSuper}, Format "%g %14.12e", File outputPower];
                    Print[{$Time}, Format "Time %g saved."];
                EndIf

                If(Flag_WallTime)
                    Evaluate[ $WallTime = $WallTimeGenerate + $WallTimeSolve + $WallTimePostPro ];
                    Print[{$WallTimeGenerate, $WallTimeSolve, $WallTimePostPro, $WallTime},
                        Format "Wall time: Gen %g, Solve %g, PP %g, TOT %g"];
                EndIf

                If(Flag_try_ASM_before_MUMPS)
                    // switch back to fast linear solver
                    SetGlobalSolverOptions[FastLinearSolver];
                EndIf

                Test[$Time >= AtIndex[$elapsedCTI]{List[controlTimeInstants]} - 1e-6 ]{
                    // counting control time instants
                    Evaluate[$elapsedCTI = $elapsedCTI + 1];
                    SetDTime[dt];
                }
            } // ----- End time loop -----
            // Print information about the resolution and the nonlinear iterations
            Print[{$syscount}, Format "Total number of linear systems solved: %g"];
        }
    }
}