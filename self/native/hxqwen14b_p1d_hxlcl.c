// hxqwen14b_p1d_hxlcl.c — real syscall-wrapper definitions for the
// standalone Phase 1d correctness driver. In the normal build these live in
// the hexa runtime (self/runtime_core.c); the driver doesn't link the runtime,
// so we provide the same unhooked POSIX wrappers here. Only the load/
// safetensors path uses them; the LoRA fwd/bwd path under test does not.

#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <stddef.h>

int hxlcl_open_sys(const char* path, int flags) { return open(path, flags); }
int hxlcl_close(int fd) { return close(fd); }
long hxlcl_read(int fd, void* buf, size_t n) { return (long)read(fd, buf, n); }
int hxlcl_fstat(int fd, struct stat* st) { return fstat(fd, st); }
int hxlcl_stat(const char* path, struct stat* st) { return stat(path, st); }
void* hxlcl_mmap(void* addr, size_t len, int prot, int flags, int fd, off_t off) {
    return mmap(addr, len, prot, flags, fd, off);
}
