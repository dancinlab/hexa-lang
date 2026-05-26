/* test/native_build/poc_rt_exit_caller.c
 *
 * Chunk B/A bridge PoC — tiny C caller for hexa-emitted rt_exit .o.
 *
 * Links against /tmp/poc_rt_exit.o (produced by poc_rt_exit_obj_emit.hexa).
 * The .o exports `_hexa_main` (Mach-O underscore convention → `hexa_main`
 * in C). rt_exit's 16 bytes set x16=SYS_exit and svc #0x80; they DO NOT
 * touch x0, so the syscall consumes whatever x0 the caller set.
 *
 * On AArch64 macOS ABI, the first arg to hexa_main is passed in x0.
 * We pass 42 → exit(42) → shell sees rc=42.
 *
 * Compile:
 *   clang poc_rt_exit_caller.c /tmp/poc_rt_exit.o -o /tmp/poc_rt_exit_run
 * Run:
 *   /tmp/poc_rt_exit_run ; echo "rc=$?"     → rc=42
 *
 * NO direct exit/_exit syscall here. The C side ONLY tail-calls into
 * hexa-emitted bytes; control NEVER returns. main() takes a noreturn
 * branch into hexa_main, and the svc terminates the process.
 */

extern void hexa_main(long x0);

int main(void) {
    hexa_main(42);
    return 99;  /* unreachable — hexa_main does svc #0x80 exit */
}
