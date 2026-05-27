// b_data.c — Phase-H inc4 PoC companion: provides the `MSG` __cstring
// payload used by a_main.c's write(1, MSG, 3) call.
//
// Kept separate so the linker exercises cross-object PAGE21/PAGEOFF12
// reloc (inc2-proven) AND the new dyld bind (inc4) in the SAME binary
// — both paths must coexist for the result to run.

const char MSG[] = "hi\n";
