/* self/native/exec_pipe.c -- fork + exec with separated stdout/stderr pipes.
 *
 * Included from self/runtime.c (NOT a standalone TU).
 *
 * Unlike hexa_pty_forkexec (which uses a pty so stdout and stderr both
 * fall down the master_fd), this binding gives the caller two distinct
 * fds — needed by sshd to route stdout to CHANNEL_DATA and stderr to
 * CHANNEL_EXTENDED_DATA(1) per RFC 4254 §5.2.
 *
 * Exports (codegen direct-emit):
 *   hexa_exec_pipe_open(argv, env)
 *     -> map { pid:int, stdout_fd:int, stderr_fd:int, stdin_fd:int }
 *     or { error: string }
 *
 * Lifecycle: caller is responsible for net_close(stdout_fd) /
 * net_close(stderr_fd) / net_close(stdin_fd) and proc_wait(pid).
 */

#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

HexaVal hexa_exec_pipe_open(HexaVal argv_v, HexaVal env_v) {
    if (!HX_IS_ARRAY(argv_v)) return _crypto_error("exec_pipe_open: argv must be array");
    int argc = HX_ARR_LEN(argv_v);
    if (argc < 1) return _crypto_error("exec_pipe_open: empty argv");
    /* Materialize argv */
    char** argv = (char**)malloc(sizeof(char*) * (size_t)(argc + 1));
    if (!argv) return _crypto_error("exec_pipe_open: oom argv");
    for (int i = 0; i < argc; i++) {
        HexaVal v = HX_ARR_ITEMS(argv_v)[i];
        const char* s = HX_IS_STR(v) ? HX_STR(v) : "";
        argv[i] = strdup(s ? s : "");
    }
    argv[argc] = NULL;

    /* Materialize env: [string] of "KEY=VALUE" entries (NULL-terminated). */
    char** envp = NULL;
    int envc = 0;
    if (HX_IS_ARRAY(env_v)) {
        envc = HX_ARR_LEN(env_v);
        envp = (char**)malloc(sizeof(char*) * (size_t)(envc + 1));
        for (int i = 0; i < envc; i++) {
            HexaVal v = HX_ARR_ITEMS(env_v)[i];
            const char* s = HX_IS_STR(v) ? HX_STR(v) : "";
            envp[i] = strdup(s ? s : "");
        }
        envp[envc] = NULL;
    }

    int p_stdin[2], p_stdout[2], p_stderr[2];
    if (pipe(p_stdin)  != 0) { /* fall through to cleanup */ goto fail_pipe; }
    if (pipe(p_stdout) != 0) { close(p_stdin[0]); close(p_stdin[1]); goto fail_pipe; }
    if (pipe(p_stderr) != 0) {
        close(p_stdin[0]); close(p_stdin[1]);
        close(p_stdout[0]); close(p_stdout[1]);
        goto fail_pipe;
    }

    pid_t pid = fork();
    if (pid < 0) {
        close(p_stdin[0]); close(p_stdin[1]);
        close(p_stdout[0]); close(p_stdout[1]);
        close(p_stderr[0]); close(p_stderr[1]);
        for (int i = 0; i < argc; i++) free(argv[i]);
        free(argv);
        if (envp) { for (int i = 0; i < envc; i++) free(envp[i]); free(envp); }
        return _crypto_error("exec_pipe_open: fork failed");
    }
    if (pid == 0) {
        /* child */
        dup2(p_stdin[0],  STDIN_FILENO);
        dup2(p_stdout[1], STDOUT_FILENO);
        dup2(p_stderr[1], STDERR_FILENO);
        close(p_stdin[0]);  close(p_stdin[1]);
        close(p_stdout[0]); close(p_stdout[1]);
        close(p_stderr[0]); close(p_stderr[1]);
        if (envp && envc > 0) {
            execve(argv[0], argv, envp);
        } else {
            execvp(argv[0], argv);
        }
        /* exec failed */
        _exit(127);
    }
    /* parent */
    close(p_stdin[0]);
    close(p_stdout[1]);
    close(p_stderr[1]);
    for (int i = 0; i < argc; i++) free(argv[i]);
    free(argv);
    if (envp) { for (int i = 0; i < envc; i++) free(envp[i]); free(envp); }

    HexaVal m = hexa_map_new();
    hexa_map_set(m, "pid",        hexa_int((int64_t)pid));
    hexa_map_set(m, "stdin_fd",   hexa_int((int64_t)p_stdin[1]));
    hexa_map_set(m, "stdout_fd",  hexa_int((int64_t)p_stdout[0]));
    hexa_map_set(m, "stderr_fd",  hexa_int((int64_t)p_stderr[0]));
    return m;

fail_pipe:
    for (int i = 0; i < argc; i++) free(argv[i]);
    free(argv);
    if (envp) { for (int i = 0; i < envc; i++) free(envp[i]); free(envp); }
    return _crypto_error("exec_pipe_open: pipe() failed");
}
