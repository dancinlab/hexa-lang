// a_main.c — object A: entry `_start`. Exercises a FULL multi-section
// image laid out by tool/hexa_ld.hexa (phase-H inc3):
//
//   (a) read-only string in __cstring  (extern `ms_str`, object B)
//   (b) initialized mutable global in __data (extern `ms_init`, object B)
//   (c) zero-init global in __bss (extern `ms_zero`, object B)
//
// It reads (b), copies it into (c), reads (c) back, writes (a) to fd 1,
// then exits with the value read from (c). All via raw `svc #0x80`
// syscalls — freestanding, NO libc, NO dyld imports — so this binary
// exercises ONLY the cross-object PAGE21/PAGEOFF12 + the __TEXT/__DATA
// multi-section layout, exactly the gap this increment closes. The
// GOT / dyld function-import path is deliberately NOT touched (deferred
// to the next increment).
//
// Control/INPUT only — produced with `clang -c`, then linked by
// hexa_ld (NO clang/ld/as at link time).
//
// Expected behaviour:
//   ms_init   = 7   (in __data)
//   ms_zero   = 0   (in __bss)  → set to ms_init → 7
//   stdout    = "ms ok\n"  (6 bytes, in __cstring)
//   exit code = 7

extern const char ms_str[];      // __cstring  (read-only)
extern int        ms_init;       // __data     (initialized = 7)
extern int        ms_zero;       // __bss      (zero-init)

__attribute__((naked, used))
void _start(void) {
    __asm__ volatile(
        // x9 = &ms_init  (adrp+add → __data)
        "adrp x9, _ms_init@PAGE\n"
        "add  x9, x9, _ms_init@PAGEOFF\n"
        "ldr  w10, [x9]\n"               // w10 = ms_init = 7  (LDR-scaled PAGEOFF? no, this is on x9 already)
        // x11 = &ms_zero (adrp+add → __bss)
        "adrp x11, _ms_zero@PAGE\n"
        "add  x11, x11, _ms_zero@PAGEOFF\n"
        "str  w10, [x11]\n"              // ms_zero = ms_init = 7   (WRITE to __bss)
        "ldr  w12, [x11]\n"              // w12 = ms_zero (read back) = 7
        // write(1, ms_str, 6)
        "adrp x1, _ms_str@PAGE\n"
        "add  x1, x1, _ms_str@PAGEOFF\n" // x1 = &ms_str  (__cstring)
        "mov  x0, #1\n"                  // fd = stdout
        "mov  x2, #6\n"                  // len = 6 ("ms ok\n")
        "mov  x16, #4\n"                 // SYS_write
        "svc  #0x80\n"
        // exit(w12)  — should be 7
        "mov  x0, x12\n"
        "mov  x16, #1\n"                 // SYS_exit
        "svc  #0x80\n"
    );
}
