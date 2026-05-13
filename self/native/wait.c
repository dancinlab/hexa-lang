/* self/native/wait.c -- waitpid(2) wrapper (POSIX).
 *
 * Included from self/runtime.c via `#include "native/wait.c"`. NOT a
 * standalone TU; relies on the runtime.c types (HexaVal, HX_IS_*,
 * hexa_map_*).
 *
 * Symbols exported (codegen direct-emit):
 *   hexa_proc_wait(pid, flags)   -> map { pid, exited, signaled, exit_code, term_sig, raw_status }
 *                                    pid == -1 (any child) supported.
 *                                    flags: 0 = blocking, WNOHANG = non-blocking.
 *                                    On WNOHANG with no children ready: returns map with pid=0.
 *                                    On error: returns map { error, errno }.
 *
 * RFC slot: stdlib-for-cpu-port.md P1 "signal-ext: SIGCHLD reaping".
 * Consumer: pty_forkexec / pool_on / any hexa fork+exec pattern that
 * needs to reap its zombies.
 */

#include <sys/wait.h>

HexaVal hexa_proc_wait(HexaVal pid_v, HexaVal flags_v) {
    HexaVal m = hexa_map_new();
    int wpid = HX_IS_INT(pid_v) ? (int)HX_INT(pid_v) : -1;
    int flags = HX_IS_INT(flags_v) ? (int)HX_INT(flags_v) : 0;
    int status = 0;
    int rc = waitpid((pid_t)wpid, &status, flags);
    if (rc < 0) {
        hexa_map_set(m, "error", hexa_str(strerror(errno)));
        hexa_map_set(m, "errno", hexa_int((int64_t)errno));
        hexa_map_set(m, "pid",   hexa_int((int64_t)-1));
        return m;
    }
    /* rc == 0 with WNOHANG means no child has changed state. Surface
     * as pid=0 + the caller's flags hint; no exit info. */
    hexa_map_set(m, "pid",        hexa_int((int64_t)rc));
    hexa_map_set(m, "raw_status", hexa_int((int64_t)status));
    if (rc == 0) {
        hexa_map_set(m, "exited",    hexa_bool(0));
        hexa_map_set(m, "signaled",  hexa_bool(0));
        hexa_map_set(m, "exit_code", hexa_int(0));
        hexa_map_set(m, "term_sig",  hexa_int(0));
        return m;
    }
    int exited   = WIFEXITED(status) ? 1 : 0;
    int signaled = WIFSIGNALED(status) ? 1 : 0;
    int code     = exited   ? WEXITSTATUS(status) : 0;
    int tsig     = signaled ? WTERMSIG(status)    : 0;
    hexa_map_set(m, "exited",    hexa_bool(exited));
    hexa_map_set(m, "signaled",  hexa_bool(signaled));
    hexa_map_set(m, "exit_code", hexa_int((int64_t)code));
    hexa_map_set(m, "term_sig",  hexa_int((int64_t)tsig));
    return m;
}

/* Constants caller can pass as `flags`. Codegen direct-emits these
 * by name via `proc_wait_flag_const(name)` so the values stay in
 * sync with <sys/wait.h>. */
HexaVal hexa_proc_wait_flag_const(HexaVal name_v) {
    if (!HX_IS_STR(name_v)) return hexa_int(0);
    const char* n = HX_STR(name_v);
    if (strcmp(n, "WNOHANG")   == 0) return hexa_int((int64_t)WNOHANG);
    if (strcmp(n, "WUNTRACED") == 0) return hexa_int((int64_t)WUNTRACED);
#ifdef WCONTINUED
    if (strcmp(n, "WCONTINUED")== 0) return hexa_int((int64_t)WCONTINUED);
#endif
    return hexa_int(0);
}
