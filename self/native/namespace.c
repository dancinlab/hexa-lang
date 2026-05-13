/* self/native/namespace.c -- Linux unshare(2) / setns(2) / pivot_root(2)
 * + clone flag constants.
 *
 * Included from self/runtime.c via `#include "native/namespace.c"`. NOT
 * a standalone TU.
 *
 * Symbols exported (codegen direct-emit):
 *   hexa_unshare(flags)              -> 0 or -errno
 *   hexa_setns(fd, nstype)           -> 0 or -errno
 *   hexa_pivot_root(new_root, put_old) -> 0 or -errno
 *   hexa_namespace_clone_const(name) -> int (CLONE_NEW* constant value)
 *
 * RFC: ~/core/hexa-lang/incoming/patches/stdlib-os-namespace-linux.md
 * Motivation: u-root/cpu port stage-B -- per-session mount / user /
 * net / pid namespace for the cpu daemon's child process.
 *
 * Platform behavior:
 *   Linux  -- real syscall via sched.h / sys/mount.h
 *   macOS  -- returns -ENOSYS; namespaces are a Linux-only concept,
 *             this is the right shape for graceful degradation.
 */

#ifdef __linux__
/* Need _GNU_SOURCE for unshare, setns, pivot_root, CLONE_NEW* flags.
 * cmd_build adds it on Linux, but defining it here is harmless on
 * a build that already has it. */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <sched.h>
#include <linux/sched.h>     /* CLONE_NEW* */
#include <sys/syscall.h>
#include <sys/mount.h>
#include <unistd.h>
#endif

HexaVal hexa_unshare(HexaVal flags_v) {
#ifdef __linux__
    if (!HX_IS_INT(flags_v)) return hexa_int((int64_t)-EINVAL);
    if (unshare((int)HX_INT(flags_v)) < 0) return hexa_int((int64_t)-errno);
    return hexa_int(0);
#else
    (void)flags_v;
    return hexa_int((int64_t)-ENOSYS);
#endif
}

HexaVal hexa_setns(HexaVal fd_v, HexaVal nstype_v) {
#ifdef __linux__
    if (!HX_IS_INT(fd_v) || !HX_IS_INT(nstype_v)) return hexa_int((int64_t)-EINVAL);
    if (setns((int)HX_INT(fd_v), (int)HX_INT(nstype_v)) < 0) return hexa_int((int64_t)-errno);
    return hexa_int(0);
#else
    (void)fd_v; (void)nstype_v;
    return hexa_int((int64_t)-ENOSYS);
#endif
}

HexaVal hexa_pivot_root(HexaVal new_root_v, HexaVal put_old_v) {
#ifdef __linux__
    if (!HX_IS_STR(new_root_v) || !HX_IS_STR(put_old_v)) return hexa_int((int64_t)-EINVAL);
    long r = syscall(SYS_pivot_root, HX_STR(new_root_v), HX_STR(put_old_v));
    if (r < 0) return hexa_int((int64_t)-errno);
    return hexa_int(0);
#else
    (void)new_root_v; (void)put_old_v;
    return hexa_int((int64_t)-ENOSYS);
#endif
}

/* CLONE_NEW* constants by name. Lets hexa code do:
 *   let CLONE_NEWNS = namespace_clone_const("CLONE_NEWNS")
 * without exposing every flag as a separate const builtin.
 * Returns 0 for unknown names (Linux callers should not pass them).
 */
HexaVal hexa_namespace_clone_const(HexaVal name_v) {
#ifdef __linux__
    if (!HX_IS_STR(name_v)) return hexa_int(0);
    const char* n = HX_STR(name_v);
    if (strcmp(n, "CLONE_NEWNS")     == 0) return hexa_int((int64_t)CLONE_NEWNS);
    if (strcmp(n, "CLONE_NEWUTS")    == 0) return hexa_int((int64_t)CLONE_NEWUTS);
    if (strcmp(n, "CLONE_NEWIPC")    == 0) return hexa_int((int64_t)CLONE_NEWIPC);
    if (strcmp(n, "CLONE_NEWPID")    == 0) return hexa_int((int64_t)CLONE_NEWPID);
    if (strcmp(n, "CLONE_NEWNET")    == 0) return hexa_int((int64_t)CLONE_NEWNET);
    if (strcmp(n, "CLONE_NEWUSER")   == 0) return hexa_int((int64_t)CLONE_NEWUSER);
    if (strcmp(n, "CLONE_NEWCGROUP") == 0) return hexa_int((int64_t)CLONE_NEWCGROUP);
    if (strcmp(n, "CLONE_NEWTIME")   == 0) return hexa_int((int64_t)CLONE_NEWTIME);
    return hexa_int(0);
#else
    (void)name_v;
    /* On non-Linux, return the canonical Linux values so portable code can
     * be written without #ifdef. The actual unshare() will still return
     * -ENOSYS, but the constants are useful for serialization / docs. */
    if (!HX_IS_STR(name_v)) return hexa_int(0);
    const char* n = HX_STR(name_v);
    if (strcmp(n, "CLONE_NEWNS")     == 0) return hexa_int(0x00020000);
    if (strcmp(n, "CLONE_NEWUTS")    == 0) return hexa_int(0x04000000);
    if (strcmp(n, "CLONE_NEWIPC")    == 0) return hexa_int(0x08000000);
    if (strcmp(n, "CLONE_NEWUSER")   == 0) return hexa_int(0x10000000);
    if (strcmp(n, "CLONE_NEWPID")    == 0) return hexa_int(0x20000000);
    if (strcmp(n, "CLONE_NEWNET")    == 0) return hexa_int(0x40000000);
    if (strcmp(n, "CLONE_NEWCGROUP") == 0) return hexa_int(0x02000000);
    if (strcmp(n, "CLONE_NEWTIME")   == 0) return hexa_int(0x00000080);
    return hexa_int(0);
#endif
}
