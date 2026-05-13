/* self/native/pty.c -- POSIX pseudo-terminal pair + termios.
 *
 * Included from self/runtime.c via `#include "native/pty.c"`. NOT a
 * standalone TU -- relies on the runtime.c types/macros (HexaVal,
 * HX_IS_xx, HX_INT/HX_STR, hexa_map_xx, hexa_array_xx).
 *
 * Symbols exported (8 primitives via TAG_FN shims):
 *   hexa_pty_open()                              -> map {master, slave, slave_name} or {error}
 *   hexa_pty_get_winsize(fd)                     -> map {rows, cols, xpix, ypix} or {error}
 *   hexa_pty_set_winsize(fd, r, c, xp, yp)       -> 0 or -errno
 *   hexa_tcgetattr(fd)                           -> map {iflag, oflag, cflag, lflag, cc[]} or {error}
 *   hexa_tcsetattr(fd, when, attrs)              -> 0 or -errno
 *   hexa_tty_isatty(fd)                          -> bool
 *   hexa_tty_ttyname(fd)                         -> string or ""
 *   hexa_pty_forkexec(argv, env, rows, cols)     -> map {pid, master_fd} or {error}
 *
 * RFC: ~/core/hexa-lang/incoming/patches/stdlib-os-pty.md
 * Cross-platform: macOS (libsystem) + Linux (glibc/musl). NCCS = 20 on
 * both. Flag bits differ; we pass-through the kernel's u32 values
 * untouched -- hexa-side make_raw() applies the masks.
 */

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/types.h>

#ifdef __APPLE__
#include <util.h>     /* forkpty on macOS */
#else
#include <pty.h>      /* forkpty on glibc -- link with -lutil */
#endif

/* Helper: build a map-shape HexaVal for an error result. */
static HexaVal _hexa_pty_err(int en, const char* tag) {
    HexaVal m = hexa_map_new();
    char buf[128];
    snprintf(buf, sizeof(buf), "%s: %s", tag, strerror(en));
    hexa_map_set(m, "error", hexa_str(buf));
    hexa_map_set(m, "errno", hexa_int((int64_t)en));
    return m;
}

/* --- pty_open: open a master/slave pair via posix_openpt + grantpt + unlockpt --- */
HexaVal hexa_pty_open(void) {
    int master = posix_openpt(O_RDWR | O_NOCTTY);
    if (master < 0) return _hexa_pty_err(errno, "posix_openpt");
    if (grantpt(master) < 0)  { int e = errno; close(master); return _hexa_pty_err(e, "grantpt"); }
    if (unlockpt(master) < 0) { int e = errno; close(master); return _hexa_pty_err(e, "unlockpt"); }
    char name_buf[256];
#ifdef __APPLE__
    /* Darwin: ptsname_r doesn't exist; ptsname is documented thread-safe on macOS. */
    const char* nm = ptsname(master);
    if (!nm) { int e = errno; close(master); return _hexa_pty_err(e, "ptsname"); }
    strncpy(name_buf, nm, sizeof(name_buf) - 1);
    name_buf[sizeof(name_buf) - 1] = '\0';
#else
    if (ptsname_r(master, name_buf, sizeof(name_buf)) != 0) {
        int e = errno; close(master); return _hexa_pty_err(e, "ptsname_r");
    }
#endif
    int slave = open(name_buf, O_RDWR | O_NOCTTY);
    if (slave < 0) { int e = errno; close(master); return _hexa_pty_err(e, "open(slave)"); }
    HexaVal m = hexa_map_new();
    hexa_map_set(m, "master",     hexa_int((int64_t)master));
    hexa_map_set(m, "slave",      hexa_int((int64_t)slave));
    hexa_map_set(m, "slave_name", hexa_str(name_buf));
    return m;
}

/* --- window-size ioctl --- */
HexaVal hexa_pty_get_winsize(HexaVal fd_v) {
    if (!HX_IS_INT(fd_v)) return _hexa_pty_err(EINVAL, "pty_get_winsize");
    int fd = (int)HX_INT(fd_v);
    struct winsize w;
    if (ioctl(fd, TIOCGWINSZ, &w) < 0) return _hexa_pty_err(errno, "TIOCGWINSZ");
    HexaVal m = hexa_map_new();
    hexa_map_set(m, "rows", hexa_int((int64_t)w.ws_row));
    hexa_map_set(m, "cols", hexa_int((int64_t)w.ws_col));
    hexa_map_set(m, "xpix", hexa_int((int64_t)w.ws_xpixel));
    hexa_map_set(m, "ypix", hexa_int((int64_t)w.ws_ypixel));
    return m;
}

HexaVal hexa_pty_set_winsize(HexaVal fd_v, HexaVal r_v, HexaVal c_v, HexaVal xp_v, HexaVal yp_v) {
    if (!HX_IS_INT(fd_v)) return hexa_int(-EINVAL);
    struct winsize w;
    w.ws_row    = (unsigned short)(HX_IS_INT(r_v)  ? HX_INT(r_v)  : 0);
    w.ws_col    = (unsigned short)(HX_IS_INT(c_v)  ? HX_INT(c_v)  : 0);
    w.ws_xpixel = (unsigned short)(HX_IS_INT(xp_v) ? HX_INT(xp_v) : 0);
    w.ws_ypixel = (unsigned short)(HX_IS_INT(yp_v) ? HX_INT(yp_v) : 0);
    if (ioctl((int)HX_INT(fd_v), TIOCSWINSZ, &w) < 0) return hexa_int((int64_t)-errno);
    return hexa_int(0);
}

/* --- termios get/set --- */
HexaVal hexa_tcgetattr(HexaVal fd_v) {
    if (!HX_IS_INT(fd_v)) return _hexa_pty_err(EINVAL, "tcgetattr");
    struct termios t;
    if (tcgetattr((int)HX_INT(fd_v), &t) < 0) return _hexa_pty_err(errno, "tcgetattr");
    HexaVal m = hexa_map_new();
    hexa_map_set(m, "iflag", hexa_int((int64_t)t.c_iflag));
    hexa_map_set(m, "oflag", hexa_int((int64_t)t.c_oflag));
    hexa_map_set(m, "cflag", hexa_int((int64_t)t.c_cflag));
    hexa_map_set(m, "lflag", hexa_int((int64_t)t.c_lflag));
    /* cc array -- pack into a HexaVal array of ints. */
    HexaVal cc_arr = hexa_array_new();
    for (size_t i = 0; i < NCCS; i++) {
        cc_arr = hexa_array_push(cc_arr, hexa_int((int64_t)(unsigned char)t.c_cc[i]));
    }
    hexa_map_set(m, "cc", cc_arr);
    return m;
}

HexaVal hexa_tcsetattr(HexaVal fd_v, HexaVal when_v, HexaVal attrs_v) {
    if (!HX_IS_INT(fd_v) || !HX_IS_INT(when_v)) return hexa_int(-EINVAL);
    int fd = (int)HX_INT(fd_v);
    int when = (int)HX_INT(when_v);
    /* Read current settings as the base -- caller's map may not carry every field. */
    struct termios t;
    if (tcgetattr(fd, &t) < 0) return hexa_int((int64_t)-errno);
    if (HX_IS_MAP(attrs_v)) {
        HexaVal v;
        v = hexa_map_get(attrs_v, "iflag"); if (HX_IS_INT(v)) t.c_iflag = (tcflag_t)HX_INT(v);
        v = hexa_map_get(attrs_v, "oflag"); if (HX_IS_INT(v)) t.c_oflag = (tcflag_t)HX_INT(v);
        v = hexa_map_get(attrs_v, "cflag"); if (HX_IS_INT(v)) t.c_cflag = (tcflag_t)HX_INT(v);
        v = hexa_map_get(attrs_v, "lflag"); if (HX_IS_INT(v)) t.c_lflag = (tcflag_t)HX_INT(v);
        v = hexa_map_get(attrs_v, "cc");
        if (HX_IS_ARRAY(v)) {
            int n = HX_ARR_LEN(v);
            int lim = (n < (int)NCCS) ? n : (int)NCCS;
            for (int i = 0; i < lim; i++) {
                HexaVal cv = hexa_array_get(v, (int64_t)i);
                if (HX_IS_INT(cv)) t.c_cc[i] = (cc_t)HX_INT(cv);
            }
        }
    }
    if (tcsetattr(fd, when, &t) < 0) return hexa_int((int64_t)-errno);
    return hexa_int(0);
}

/* --- tty helpers --- */
HexaVal hexa_tty_isatty(HexaVal fd_v) {
    if (!HX_IS_INT(fd_v)) return hexa_bool(0);
    return hexa_bool(isatty((int)HX_INT(fd_v)) == 1);
}

HexaVal hexa_tty_ttyname(HexaVal fd_v) {
    if (!HX_IS_INT(fd_v)) return hexa_str("");
    const char* nm = ttyname((int)HX_INT(fd_v));
    return hexa_str(nm ? nm : "");
}

/* --- pty_forkexec(argv, env, rows, cols): forkpty-style spawn ---
 * argv  : array of strings, argv[0] is the program (resolved via PATH)
 * env   : array of "KEY=VAL" strings, or empty array = inherit
 * rows  : initial pty rows  (0 = leave kernel default)
 * cols  : initial pty cols
 *
 * Returns {pid, master_fd} on success, {error, errno} on failure.
 * The slave is dup'd onto stdin/stdout/stderr in the child + made the
 * controlling terminal; the parent only retains master_fd.
 */
HexaVal hexa_pty_forkexec(HexaVal argv_v, HexaVal env_v, HexaVal rows_v, HexaVal cols_v) {
    if (!HX_IS_ARRAY(argv_v)) return _hexa_pty_err(EINVAL, "pty_forkexec");
    int argc = HX_ARR_LEN(argv_v);
    if (argc < 1) return _hexa_pty_err(EINVAL, "pty_forkexec: empty argv");
    /* Marshal argv. */
    char** argv = (char**)calloc((size_t)argc + 1, sizeof(char*));
    if (!argv) return _hexa_pty_err(ENOMEM, "pty_forkexec");
    for (int i = 0; i < argc; i++) {
        HexaVal s = hexa_array_get(argv_v, (int64_t)i);
        const char* p = HX_IS_STR(s) ? HX_STR(s) : "";
        argv[i] = strdup(p);
    }
    /* Marshal env. */
    char** envp = NULL;
    int envc = HX_IS_ARRAY(env_v) ? HX_ARR_LEN(env_v) : 0;
    if (envc > 0) {
        envp = (char**)calloc((size_t)envc + 1, sizeof(char*));
        for (int i = 0; i < envc; i++) {
            HexaVal s = hexa_array_get(env_v, (int64_t)i);
            envp[i] = strdup(HX_IS_STR(s) ? HX_STR(s) : "");
        }
    }
    /* Optional initial winsize. */
    struct winsize w;
    struct winsize* wp = NULL;
    int rows = HX_IS_INT(rows_v) ? (int)HX_INT(rows_v) : 0;
    int cols = HX_IS_INT(cols_v) ? (int)HX_INT(cols_v) : 0;
    if (rows > 0 && cols > 0) {
        w.ws_row = (unsigned short)rows; w.ws_col = (unsigned short)cols;
        w.ws_xpixel = 0; w.ws_ypixel = 0;
        wp = &w;
    }
    int master = -1;
    pid_t pid = forkpty(&master, NULL, NULL, wp);
    if (pid < 0) {
        int e = errno;
        for (int i = 0; i < argc; i++) free(argv[i]);
        free(argv);
        if (envp) { for (int i = 0; i < envc; i++) free(envp[i]); free(envp); }
        return _hexa_pty_err(e, "forkpty");
    }
    if (pid == 0) {
        /* child -- exec the program */
        if (envp) execve(argv[0], argv, envp); /* with env */
        else      execvp(argv[0], argv);       /* inherit env */
        /* exec failed -- write a tiny diag then exit. The pty is already
         * connected, so the parent sees this on master read. */
        const char* msg = "[pty_forkexec] exec failed\n";
        ssize_t _w = write(STDERR_FILENO, msg, strlen(msg)); (void)_w;
        _exit(127);
    }
    /* parent -- cleanup our argv/env duplicates */
    for (int i = 0; i < argc; i++) free(argv[i]);
    free(argv);
    if (envp) { for (int i = 0; i < envc; i++) free(envp[i]); free(envp); }
    HexaVal m = hexa_map_new();
    hexa_map_set(m, "pid",       hexa_int((int64_t)pid));
    hexa_map_set(m, "master_fd", hexa_int((int64_t)master));
    return m;
}

/* --- TAG_FN shim globals --- */
HexaVal pty_open;
HexaVal pty_get_winsize;
HexaVal pty_set_winsize;
HexaVal pty_tcgetattr;       /* aliased so it doesn't collide with libc-style hexa_tcgetattr */
HexaVal pty_tcsetattr;
HexaVal tty_isatty;
HexaVal tty_ttyname;
HexaVal pty_forkexec;

static void _hexa_init_pty_fn_shims(void) {
    pty_open         = hexa_fn_new((void*)hexa_pty_open,         0);
    pty_get_winsize  = hexa_fn_new((void*)hexa_pty_get_winsize,  1);
    pty_set_winsize  = hexa_fn_new((void*)hexa_pty_set_winsize,  5);
    pty_tcgetattr    = hexa_fn_new((void*)hexa_tcgetattr,        1);
    pty_tcsetattr    = hexa_fn_new((void*)hexa_tcsetattr,        3);
    tty_isatty       = hexa_fn_new((void*)hexa_tty_isatty,       1);
    tty_ttyname      = hexa_fn_new((void*)hexa_tty_ttyname,      1);
    pty_forkexec     = hexa_fn_new((void*)hexa_pty_forkexec,     4);
}
