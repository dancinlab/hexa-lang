// a_main.c — Phase-H inc5 PoC: first dyld DATA import (no __stubs).
//
// Exercises the GOT-only data-import path that inc4 deliberately
// skipped:
//
//   `adrp x9, _sym@GOTPAGE`         (ARM64_RELOC_GOT_LOAD_PAGE21)
//   `ldr  x9, [x9, _sym@GOTPAGEOFF]` (ARM64_RELOC_GOT_LOAD_PAGEOFF12)
//   `ldr  x10, [x9]`                 (dereference the resolved data)
//
// No __stubs entry is emitted for a data import — user code reads
// the __got slot directly, which dyld populates at load time via
// LC_DYLD_CHAINED_FIXUPS (same bind format as function imports;
// only difference is the absence of a __stubs trampoline).
//
// We pick `environ` (a libc-exported `char**` global) because it is
// reliably present on every macOS / iOS host as a PUBLIC data export
// (re-exported through libSystem.B.dylib), has a known stable name,
// and crucially does NOT require us to write to it — read-only deref
// is all we need to verify the bind. Earlier candidate
// `___stack_chk_guard` was dropped: that symbol is a PRIVATE libc
// SSP cookie and is NOT externally extern-visible (clang itself
// refuses to link against it from a normal `extern long ...` ref).
//
// Control/INPUT: compiled with `clang -c` to a .o that REFERENCES
// `___stack_chk_guard` via @GOTPAGE/@GOTPAGEOFF (n_sect=0 extern_ref
// + kind 5/6 relocs); linked by hexa_ld (NO clang/ld/as in the
// produced exe's link).
//
// Expected behaviour:
//   stdout    = ""           (no output — we only deref the value)
//   exit code = 0            (raw svc #0x80 SYS_exit; success path
//                             means the dyld bind + adrp/ldr patch
//                             both worked — a broken bind would
//                             segfault on the deref of x9)

extern char **environ;

__attribute__((naked, used))
void _start(void) {
    __asm__ volatile(
        // Load the GOT slot's address into x9, then deref to x10.
        // The two ldr instructions are deliberately separate so the
        // first (GOT_LOAD_PAGEOFF12) is unambiguously the kind-6
        // reloc target, and the second (plain load) just confirms
        // the slot's contents are a valid pointer (deref doesn't
        // crash).
        "adrp x9, _environ@GOTPAGE\n"
        "ldr  x9, [x9, _environ@GOTPAGEOFF]\n"
        // Deref — if dyld bound the slot correctly this loads the
        // `char**` pointer value; if the bind / adrp / ldr patch
        // is wrong we'd be reading a garbage address and segfault.
        "ldr  x10, [x9]\n"
        // exit(0) via raw syscall — no extern function dependency
        // (we're isolating the data-import surface to a single
        // failure mode).
        "mov  x0, #0\n"
        "mov  x16, #1\n"   // SYS_exit
        "svc  #0x80\n"
    );
}
