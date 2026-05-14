/* self/native/proc_fork.c -- fork() + setsid() + sigchld reap helpers.
 *
 * Included from self/runtime.c (NOT a standalone TU).
 *
 * Exports (codegen direct-emit):
 *   hexa_proc_fork() -> int (0 in child, child_pid in parent, -1 on error)
 *   hexa_proc_setsid() -> int (new sid or -errno)
 *   hexa_proc_reap_zombies() -> int (count of reaped zombies)
 */

#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>

HexaVal hexa_proc_fork(void) {
    pid_t pid = fork();
    if (pid < 0) return hexa_int((int64_t)-errno);
    return hexa_int((int64_t)pid);
}

HexaVal hexa_proc_setsid(void) {
    pid_t sid = setsid();
    if (sid < 0) return hexa_int((int64_t)-errno);
    return hexa_int((int64_t)sid);
}

HexaVal hexa_proc_reap_zombies(void) {
    int count = 0;
    while (1) {
        int status = 0;
        pid_t r = waitpid(-1, &status, WNOHANG);
        if (r <= 0) break;
        count++;
    }
    return hexa_int((int64_t)count);
}
