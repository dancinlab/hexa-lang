/* self/native/mount.c -- Linux mount(2) / umount(2) syscall wrappers.
 *
 * Included from self/runtime.c via `#include "native/mount.c"`. NOT
 * a standalone TU.
 *
 * Symbols exported (codegen direct-emit; no fn-value globals because
 * the names would collide with libc declarations):
 *   hexa_mount(source, target, fstype, flags, data)  -> 0 or -errno
 *   hexa_umount(target, flags)                       -> 0 or -errno
 *
 * RFC: ~/core/hexa-lang/incoming/patches/stdlib-os-mount-linux.md
 * Motivation: u-root/cpu port stage-B -- 9P / tmpfs / bind mounts for
 * the cpu-pattern's child namespace setup. Fork-storm replacement
 * (SPEC Sec16 anti-pattern: exec("mount ...")).
 *
 * Platform behavior:
 *   Linux  -- real syscall via sys/mount.h
 *   macOS  -- returns -ENOSYS; the call sites in u-root/cpu are
 *             Linux-only (session_linux.go, mount_linux.go), so the
 *             stub is informational rather than functional.
 */

#ifdef __linux__
#include <sys/mount.h>
#endif

HexaVal hexa_mount(HexaVal src_v, HexaVal tgt_v, HexaVal fs_v, HexaVal flags_v, HexaVal data_v) {
#ifdef __linux__
    if (!HX_IS_STR(src_v) || !HX_IS_STR(tgt_v) || !HX_IS_STR(fs_v))
        return hexa_int((int64_t)-EINVAL);
    const char* src = HX_STR(src_v);
    const char* tgt = HX_STR(tgt_v);
    const char* fs  = HX_STR(fs_v);
    unsigned long flags = HX_IS_INT(flags_v) ? (unsigned long)HX_INT(flags_v) : 0;
    const char* data = HX_IS_STR(data_v) ? HX_STR(data_v) : NULL;
    if (mount(src, tgt, fs, flags, data) < 0) return hexa_int((int64_t)-errno);
    return hexa_int(0);
#else
    (void)src_v; (void)tgt_v; (void)fs_v; (void)flags_v; (void)data_v;
    return hexa_int((int64_t)-ENOSYS);
#endif
}

HexaVal hexa_umount(HexaVal tgt_v, HexaVal flags_v) {
#ifdef __linux__
    if (!HX_IS_STR(tgt_v)) return hexa_int((int64_t)-EINVAL);
    const char* tgt = HX_STR(tgt_v);
    int flags = HX_IS_INT(flags_v) ? (int)HX_INT(flags_v) : 0;
    if (umount2(tgt, flags) < 0) return hexa_int((int64_t)-errno);
    return hexa_int(0);
#else
    (void)tgt_v; (void)flags_v;
    return hexa_int((int64_t)-ENOSYS);
#endif
}
