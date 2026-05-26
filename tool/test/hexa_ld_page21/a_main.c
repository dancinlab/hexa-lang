// a_main.c — object A: entry `_start`. References the `__cstring`
// symbol `hxld_msg` (defined in object B) via an adrp/add pair
// (ARM64_RELOC_PAGE21 + ARM64_RELOC_PAGEOFF12), writes the 16-byte
// string to fd 1 via a raw `svc #0` write(2), then exits(0) via svc.
//
// Control/INPUT only — produced with `clang -c`, then linked by
// hexa_ld (NO clang/ld/as at link time). Freestanding: no libc, no
// dyld imports, so this exercises ONLY cross-object PAGE21/PAGEOFF12
// + the __cstring layout — exactly the gap this increment closes.
//
// The string is 16 bytes incl. the trailing '\n' ("hi from cstring\n").
// macOS arm64 syscall ABI: x16 = syscall number, args in x0..,
// `svc #0x80`. write = 4, exit = 1.

extern const char hxld_msg[];

__attribute__((naked, used))
void _start(void) {
    __asm__ volatile(
        // x1 = &hxld_msg  (adrp PAGE21 + add PAGEOFF12 — the relocs)
        "adrp x1, _hxld_msg@PAGE\n"
        "add  x1, x1, _hxld_msg@PAGEOFF\n"
        // write(1, x1, 16)
        "mov  x0, #1\n"            // fd = stdout
        "mov  x2, #16\n"          // len = 16
        "mov  x16, #4\n"          // SYS_write
        "svc  #0x80\n"
        // exit(0)
        "mov  x0, #0\n"
        "mov  x16, #1\n"          // SYS_exit
        "svc  #0x80\n"
    );
}
