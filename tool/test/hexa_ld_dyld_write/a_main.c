// a_main.c — Phase-H inc4 PoC: first dyld import (`_write` from libSystem).
//
// Exercises the dyld function-import path that inc1/2/3 deliberately
// skipped:
//
//   `bl _write` (ARM64_RELOC_BRANCH26, n_sect=0 extern) → __stubs entry
//   → __la_symbol_ptr (or __got) slot → dyld-bound at load time.
//
// All previous inc1/2/3 PoCs reached libSystem syscalls via raw
// `svc #0x80` instructions; this one tests the actual symbol-bind
// surface that arbitrary hexa-native programs will need.
//
// Control/INPUT: compiled with `clang -c` to a .o that REFERENCES
// `_write` (n_sect=0 extern_ref); linked by hexa_ld (NO clang/ld/as in
// the produced exe's link).
//
// Expected behaviour:
//   stdout    = "hi\n"  (3 bytes via _write)
//   exit code = 0       (raw svc #0x80 SYS_exit; exit syscall doesn't
//                        need an import — we want to isolate the
//                        _write bind to a single failure surface)

// MSG defined in b_data.c (separate __cstring object — already
// validated by inc2 PAGE21/PAGEOFF12 cross-object path).
extern const char MSG[];

__attribute__((naked, used))
void _start(void) {
    __asm__ volatile(
        // x0 = fd = 1
        "mov  x0, #1\n"
        // x1 = &MSG (PAGE21 + PAGEOFF12 to __cstring) — inc2 path
        "adrp x1, _MSG@PAGE\n"
        "add  x1, x1, _MSG@PAGEOFF\n"
        // x2 = 3
        "mov  x2, #3\n"
        // call write(1, MSG, 3) — BRANCH26 reloc against extern _write
        // (this is the inc4 dyld-import gap)
        "bl   _write\n"
        // exit(0) via raw syscall — no extern dependency
        "mov  x0, #0\n"
        "mov  x16, #1\n"   // SYS_exit
        "svc  #0x80\n"
    );
}
