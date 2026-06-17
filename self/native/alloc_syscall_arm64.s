// alloc_syscall_arm64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE-ZEROC b3a alloc+syscall).
// GENERATED: tool/regen_alloc_syscall_native_s.sh — aprime _drv.hexa --emit=asm
//   --target=arm64-apple-darwin (flattened self/rt/alloc.hexa = alloc+syscall).
//   Native alloc+syscall bodies (hexa_arena_*/hexa_ptr_*/sys_*/rt_init) over the
//   M5 leaf surface (__hx_syscall6/__hx_ptr_*/__hx_target_os/__hx_str_ptr + the
//   module-global write path). hexat C-transpile cannot lower these, so they
//   enter runtime.a ONLY via this seed. RUN-proven (F-M5-GSLOT-VAL-DONE, exit 0).
//   ABI: Mach-O arm64.
; hexa-lang emit pass — target=arm64-apple-darwin
; source: /tmp/regen_alloc_syscall.G0dKVz/alloc-flat.hexa
.file 1 "self/rt/alloc.hexa"
.section __TEXT,__text,regular,pure_instructions
.globl _target_is_linux
.private_extern _target_is_linux
    .p2align 2
_target_is_linux:
    .loc 1 28 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #32 ; sp adj
__L7797_target_is_linux_bb0:
    movz x1, #1 ; __hx_target_os: 1 = darwin
    movz x0, #0 ; __hx_target_os: TAG_INT
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    add sp, sp, #32 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _target_is_darwin
.private_extern _target_is_darwin
    .p2align 2
_target_is_darwin:
    .loc 1 29 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #32 ; sp adj
__L7797_target_is_darwin_bb0:
    movz x1, #1 ; __hx_target_os: 1 = darwin
    movz x0, #0 ; __hx_target_os: TAG_INT
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    add sp, sp, #32 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl __sc0
.private_extern __sc0
    .p2align 2
__sc0:
    .loc 1 43 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #32 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797__sc0_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    mov x16, x1 ; __hx_syscall0: x16 = syscall num
    svc #0x80 ; __hx_syscall0: BSD syscall trap
    mov x1, x0 ; __hx_syscall0: payload = result
    movz x0, #0 ; __hx_syscall0: TAG_INT
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    add sp, sp, #32 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl __sc1
.private_extern __sc1
    .p2align 2
__sc1:
    .loc 1 44 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #96 ; sp adj
    stp x0, x1, [sp, #48] ; ingress param 0
    stp x2, x3, [sp, #64] ; ingress param 1
__L7797__sc1_bb0:
    ldp x7, x8, [sp, #64] ; hv load L1
    mov x9, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x10, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x11, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x12, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x13, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x14, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #48] ; hv load L0
    mov x16, x8 ; __hx_syscall6: x16 = syscall num
    mov x0, x9 ; __hx_syscall6: arg -> x0
    mov x1, x10 ; __hx_syscall6: arg -> x1
    mov x2, x11 ; __hx_syscall6: arg -> x2
    mov x3, x12 ; __hx_syscall6: arg -> x3
    mov x4, x13 ; __hx_syscall6: arg -> x4
    mov x5, x14 ; __hx_syscall6: arg -> x5
    svc #0x80 ; __hx_syscall6: BSD syscall trap
    mov x1, x0 ; __hx_syscall6: payload = result
    movz x0, #0 ; __hx_syscall6: TAG_INT
    stp x0, x1, [sp, #80] ; hv store L2
    ldp x0, x1, [sp, #80] ; hv load L2
    add sp, sp, #96 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl __sc2
.private_extern __sc2
    .p2align 2
__sc2:
    .loc 1 45 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #112 ; sp adj
    stp x0, x1, [sp, #48] ; ingress param 0
    stp x2, x3, [sp, #64] ; ingress param 1
    stp x4, x5, [sp, #80] ; ingress param 2
__L7797__sc2_bb0:
    ldp x7, x8, [sp, #64] ; hv load L1
    mov x9, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #80] ; hv load L2
    mov x10, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x11, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x12, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x13, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x14, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #48] ; hv load L0
    mov x16, x8 ; __hx_syscall6: x16 = syscall num
    mov x0, x9 ; __hx_syscall6: arg -> x0
    mov x1, x10 ; __hx_syscall6: arg -> x1
    mov x2, x11 ; __hx_syscall6: arg -> x2
    mov x3, x12 ; __hx_syscall6: arg -> x3
    mov x4, x13 ; __hx_syscall6: arg -> x4
    mov x5, x14 ; __hx_syscall6: arg -> x5
    svc #0x80 ; __hx_syscall6: BSD syscall trap
    mov x1, x0 ; __hx_syscall6: payload = result
    movz x0, #0 ; __hx_syscall6: TAG_INT
    stp x0, x1, [sp, #96] ; hv store L3
    ldp x0, x1, [sp, #96] ; hv load L3
    add sp, sp, #112 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl __sc3
.private_extern __sc3
    .p2align 2
__sc3:
    .loc 1 46 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #128 ; sp adj
    stp x0, x1, [sp, #48] ; ingress param 0
    stp x2, x3, [sp, #64] ; ingress param 1
    stp x4, x5, [sp, #80] ; ingress param 2
    stp x6, x7, [sp, #96] ; ingress param 3
__L7797__sc3_bb0:
    ldp x7, x8, [sp, #64] ; hv load L1
    mov x9, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #80] ; hv load L2
    mov x10, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #96] ; hv load L3
    mov x11, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x12, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x13, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x14, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #48] ; hv load L0
    mov x16, x8 ; __hx_syscall6: x16 = syscall num
    mov x0, x9 ; __hx_syscall6: arg -> x0
    mov x1, x10 ; __hx_syscall6: arg -> x1
    mov x2, x11 ; __hx_syscall6: arg -> x2
    mov x3, x12 ; __hx_syscall6: arg -> x3
    mov x4, x13 ; __hx_syscall6: arg -> x4
    mov x5, x14 ; __hx_syscall6: arg -> x5
    svc #0x80 ; __hx_syscall6: BSD syscall trap
    mov x1, x0 ; __hx_syscall6: payload = result
    movz x0, #0 ; __hx_syscall6: TAG_INT
    stp x0, x1, [sp, #112] ; hv store L4
    ldp x0, x1, [sp, #112] ; hv load L4
    add sp, sp, #128 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl __sc4
.private_extern __sc4
    .p2align 2
__sc4:
    .loc 1 47 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #144 ; sp adj
    stp x0, x1, [sp, #48] ; ingress param 0
    stp x2, x3, [sp, #64] ; ingress param 1
    stp x4, x5, [sp, #80] ; ingress param 2
    stp x6, x7, [sp, #96] ; ingress param 3
    ldp x9, x10, [x29, #16] ; ingress stack param 4
    stp x9, x10, [sp, #112] ; store stack param 4
__L7797__sc4_bb0:
    ldp x7, x8, [sp, #64] ; hv load L1
    mov x9, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #80] ; hv load L2
    mov x10, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #96] ; hv load L3
    mov x11, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #112] ; hv load L4
    mov x12, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x13, x8 ; __hx_syscall6: stage arg
    movz x7, #0 ; hv const_int: TAG_INT
    movz x8, #0 ; hv const_int val
    mov x14, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #48] ; hv load L0
    mov x16, x8 ; __hx_syscall6: x16 = syscall num
    mov x0, x9 ; __hx_syscall6: arg -> x0
    mov x1, x10 ; __hx_syscall6: arg -> x1
    mov x2, x11 ; __hx_syscall6: arg -> x2
    mov x3, x12 ; __hx_syscall6: arg -> x3
    mov x4, x13 ; __hx_syscall6: arg -> x4
    mov x5, x14 ; __hx_syscall6: arg -> x5
    svc #0x80 ; __hx_syscall6: BSD syscall trap
    mov x1, x0 ; __hx_syscall6: payload = result
    movz x0, #0 ; __hx_syscall6: TAG_INT
    stp x0, x1, [sp, #128] ; hv store L5
    ldp x0, x1, [sp, #128] ; hv load L5
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl __sc6
.private_extern __sc6
    .p2align 2
__sc6:
    .loc 1 48 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #176 ; sp adj
    stp x0, x1, [sp, #48] ; ingress param 0
    stp x2, x3, [sp, #64] ; ingress param 1
    stp x4, x5, [sp, #80] ; ingress param 2
    stp x6, x7, [sp, #96] ; ingress param 3
    ldp x9, x10, [x29, #16] ; ingress stack param 4
    stp x9, x10, [sp, #112] ; store stack param 4
    ldp x9, x10, [x29, #32] ; ingress stack param 5
    stp x9, x10, [sp, #128] ; store stack param 5
    ldp x9, x10, [x29, #48] ; ingress stack param 6
    stp x9, x10, [sp, #144] ; store stack param 6
__L7797__sc6_bb0:
    ldp x7, x8, [sp, #64] ; hv load L1
    mov x9, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #80] ; hv load L2
    mov x10, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #96] ; hv load L3
    mov x11, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #112] ; hv load L4
    mov x12, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #128] ; hv load L5
    mov x13, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #144] ; hv load L6
    mov x14, x8 ; __hx_syscall6: stage arg
    ldp x7, x8, [sp, #48] ; hv load L0
    mov x16, x8 ; __hx_syscall6: x16 = syscall num
    mov x0, x9 ; __hx_syscall6: arg -> x0
    mov x1, x10 ; __hx_syscall6: arg -> x1
    mov x2, x11 ; __hx_syscall6: arg -> x2
    mov x3, x12 ; __hx_syscall6: arg -> x3
    mov x4, x13 ; __hx_syscall6: arg -> x4
    mov x5, x14 ; __hx_syscall6: arg -> x5
    svc #0x80 ; __hx_syscall6: BSD syscall trap
    mov x1, x0 ; __hx_syscall6: payload = result
    movz x0, #0 ; __hx_syscall6: TAG_INT
    stp x0, x1, [sp, #160] ; hv store L7
    ldp x0, x1, [sp, #160] ; hv load L7
    add sp, sp, #176 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_READ
.private_extern _SYS_LINUX_READ
    .p2align 2
_SYS_LINUX_READ:
    .loc 1 54 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_READ_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_WRITE
.private_extern _SYS_LINUX_WRITE
    .p2align 2
_SYS_LINUX_WRITE:
    .loc 1 55 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_WRITE_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_OPEN
.private_extern _SYS_LINUX_OPEN
    .p2align 2
_SYS_LINUX_OPEN:
    .loc 1 56 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_OPEN_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #2 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_CLOSE
.private_extern _SYS_LINUX_CLOSE
    .p2align 2
_SYS_LINUX_CLOSE:
    .loc 1 57 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_CLOSE_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #3 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_STAT
.private_extern _SYS_LINUX_STAT
    .p2align 2
_SYS_LINUX_STAT:
    .loc 1 58 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_STAT_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #4 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_FSTAT
.private_extern _SYS_LINUX_FSTAT
    .p2align 2
_SYS_LINUX_FSTAT:
    .loc 1 59 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_FSTAT_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #5 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_LSEEK
.private_extern _SYS_LINUX_LSEEK
    .p2align 2
_SYS_LINUX_LSEEK:
    .loc 1 60 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_LSEEK_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #8 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_MMAP
.private_extern _SYS_LINUX_MMAP
    .p2align 2
_SYS_LINUX_MMAP:
    .loc 1 61 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_MMAP_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #9 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_MUNMAP
.private_extern _SYS_LINUX_MUNMAP
    .p2align 2
_SYS_LINUX_MUNMAP:
    .loc 1 62 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_MUNMAP_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #11 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_BRK
.private_extern _SYS_LINUX_BRK
    .p2align 2
_SYS_LINUX_BRK:
    .loc 1 63 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_BRK_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #12 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_IOCTL
.private_extern _SYS_LINUX_IOCTL
    .p2align 2
_SYS_LINUX_IOCTL:
    .loc 1 64 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_IOCTL_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #16 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_PIPE
.private_extern _SYS_LINUX_PIPE
    .p2align 2
_SYS_LINUX_PIPE:
    .loc 1 65 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_PIPE_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #22 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_NANOSLEEP
.private_extern _SYS_LINUX_NANOSLEEP
    .p2align 2
_SYS_LINUX_NANOSLEEP:
    .loc 1 66 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_NANOSLEEP_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #35 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_FORK
.private_extern _SYS_LINUX_FORK
    .p2align 2
_SYS_LINUX_FORK:
    .loc 1 67 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_FORK_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #57 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_EXECVE
.private_extern _SYS_LINUX_EXECVE
    .p2align 2
_SYS_LINUX_EXECVE:
    .loc 1 68 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_EXECVE_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #59 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_WAIT4
.private_extern _SYS_LINUX_WAIT4
    .p2align 2
_SYS_LINUX_WAIT4:
    .loc 1 69 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_WAIT4_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #61 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_DUP2
.private_extern _SYS_LINUX_DUP2
    .p2align 2
_SYS_LINUX_DUP2:
    .loc 1 70 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_DUP2_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #33 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_GETDENTS64
.private_extern _SYS_LINUX_GETDENTS64
    .p2align 2
_SYS_LINUX_GETDENTS64:
    .loc 1 71 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_GETDENTS64_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #217 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_CLOCK_GETTIME
.private_extern _SYS_LINUX_CLOCK_GETTIME
    .p2align 2
_SYS_LINUX_CLOCK_GETTIME:
    .loc 1 72 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_CLOCK_GETTIME_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #228 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_EXIT_GROUP
.private_extern _SYS_LINUX_EXIT_GROUP
    .p2align 2
_SYS_LINUX_EXIT_GROUP:
    .loc 1 73 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_EXIT_GROUP_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #231 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_UNLINKAT
.private_extern _SYS_LINUX_UNLINKAT
    .p2align 2
_SYS_LINUX_UNLINKAT:
    .loc 1 74 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_UNLINKAT_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #263 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_MKDIRAT
.private_extern _SYS_LINUX_MKDIRAT
    .p2align 2
_SYS_LINUX_MKDIRAT:
    .loc 1 75 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_MKDIRAT_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #258 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_LINUX_GETRANDOM
.private_extern _SYS_LINUX_GETRANDOM
    .p2align 2
_SYS_LINUX_GETRANDOM:
    .loc 1 76 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_LINUX_GETRANDOM_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #318 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_EXIT
.private_extern _SYS_DARWIN_EXIT
    .p2align 2
_SYS_DARWIN_EXIT:
    .loc 1 82 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_EXIT_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_FORK
.private_extern _SYS_DARWIN_FORK
    .p2align 2
_SYS_DARWIN_FORK:
    .loc 1 83 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_FORK_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #2 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_READ
.private_extern _SYS_DARWIN_READ
    .p2align 2
_SYS_DARWIN_READ:
    .loc 1 84 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_READ_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #3 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_WRITE
.private_extern _SYS_DARWIN_WRITE
    .p2align 2
_SYS_DARWIN_WRITE:
    .loc 1 85 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_WRITE_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #4 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_OPEN
.private_extern _SYS_DARWIN_OPEN
    .p2align 2
_SYS_DARWIN_OPEN:
    .loc 1 86 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_OPEN_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #5 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_CLOSE
.private_extern _SYS_DARWIN_CLOSE
    .p2align 2
_SYS_DARWIN_CLOSE:
    .loc 1 87 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_CLOSE_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #6 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_WAIT4
.private_extern _SYS_DARWIN_WAIT4
    .p2align 2
_SYS_DARWIN_WAIT4:
    .loc 1 88 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_WAIT4_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #7 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_UNLINK
.private_extern _SYS_DARWIN_UNLINK
    .p2align 2
_SYS_DARWIN_UNLINK:
    .loc 1 89 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_UNLINK_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #10 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_LSEEK
.private_extern _SYS_DARWIN_LSEEK
    .p2align 2
_SYS_DARWIN_LSEEK:
    .loc 1 90 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_LSEEK_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #199 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_EXECVE
.private_extern _SYS_DARWIN_EXECVE
    .p2align 2
_SYS_DARWIN_EXECVE:
    .loc 1 91 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_EXECVE_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #59 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_MUNMAP
.private_extern _SYS_DARWIN_MUNMAP
    .p2align 2
_SYS_DARWIN_MUNMAP:
    .loc 1 92 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_MUNMAP_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #73 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_MMAP
.private_extern _SYS_DARWIN_MMAP
    .p2align 2
_SYS_DARWIN_MMAP:
    .loc 1 93 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_MMAP_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #197 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_FSTAT64
.private_extern _SYS_DARWIN_FSTAT64
    .p2align 2
_SYS_DARWIN_FSTAT64:
    .loc 1 94 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_FSTAT64_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #189 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_GETDIRENTRIES
.private_extern _SYS_DARWIN_GETDIRENTRIES
    .p2align 2
_SYS_DARWIN_GETDIRENTRIES:
    .loc 1 95 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_GETDIRENTRIES_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #340 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_GETDIRENTRIES64
.private_extern _SYS_DARWIN_GETDIRENTRIES64
    .p2align 2
_SYS_DARWIN_GETDIRENTRIES64:
    .loc 1 96 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_GETDIRENTRIES64_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #344 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_MKDIR
.private_extern _SYS_DARWIN_MKDIR
    .p2align 2
_SYS_DARWIN_MKDIR:
    .loc 1 97 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_MKDIR_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #136 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_NANOSLEEP
.private_extern _SYS_DARWIN_NANOSLEEP
    .p2align 2
_SYS_DARWIN_NANOSLEEP:
    .loc 1 98 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_NANOSLEEP_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #197 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _SYS_DARWIN_CLOCK_GETTIME
.private_extern _SYS_DARWIN_CLOCK_GETTIME
    .p2align 2
_SYS_DARWIN_CLOCK_GETTIME:
    .loc 1 99 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_SYS_DARWIN_CLOCK_GETTIME_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #3576 ; imm 0-15
    movk x1, #512, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_read
.private_extern _sys_read
    .p2align 2
_sys_read:
    .loc 1 105 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #144 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L7797_sys_read_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_read_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_read_bb1 ; branch -> then
__L7797_sys_read_bb1:
    bl _SYS_LINUX_READ ; call SYS_LINUX_READ
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_read_bb2:
    bl _SYS_DARWIN_READ ; call SYS_DARWIN_READ
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_write
.private_extern _sys_write
    .p2align 2
_sys_write:
    .loc 1 110 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #144 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L7797_sys_write_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_write_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_write_bb1 ; branch -> then
__L7797_sys_write_bb1:
    bl _SYS_LINUX_WRITE ; call SYS_LINUX_WRITE
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_write_bb2:
    bl _SYS_DARWIN_WRITE ; call SYS_DARWIN_WRITE
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_open
.private_extern _sys_open
    .p2align 2
_sys_open:
    .loc 1 115 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #144 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L7797_sys_open_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_open_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_open_bb1 ; branch -> then
__L7797_sys_open_bb1:
    bl _SYS_LINUX_OPEN ; call SYS_LINUX_OPEN
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_open_bb2:
    bl _SYS_DARWIN_OPEN ; call SYS_DARWIN_OPEN
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_close
.private_extern _sys_close
    .p2align 2
_sys_close:
    .loc 1 120 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #112 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797_sys_close_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_close_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_close_bb1 ; branch -> then
__L7797_sys_close_bb1:
    bl _SYS_LINUX_CLOSE ; call SYS_LINUX_CLOSE
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #0] ; hv load L0
    bl __sc1 ; call _sc1
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    add sp, sp, #112 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_close_bb2:
    bl _SYS_DARWIN_CLOSE ; call SYS_DARWIN_CLOSE
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #0] ; hv load L0
    bl __sc1 ; call _sc1
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    add sp, sp, #112 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_lseek
.private_extern _sys_lseek
    .p2align 2
_sys_lseek:
    .loc 1 125 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #144 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L7797_sys_lseek_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_lseek_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_lseek_bb1 ; branch -> then
__L7797_sys_lseek_bb1:
    bl _SYS_LINUX_LSEEK ; call SYS_LINUX_LSEEK
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_lseek_bb2:
    bl _SYS_DARWIN_LSEEK ; call SYS_DARWIN_LSEEK
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_unlink
.private_extern _sys_unlink
    .p2align 2
_sys_unlink:
    .loc 1 130 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #112 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797_sys_unlink_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_unlink_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_unlink_bb1 ; branch -> then
__L7797_sys_unlink_bb1:
    bl _SYS_LINUX_UNLINKAT ; call SYS_LINUX_UNLINKAT
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #99 ; imm 0-15
    mvn x3, x3 ; hv const_int: negate
    ldp x4, x5, [sp, #0] ; hv load L0
    movz x6, #0 ; hv const_int: TAG_INT
    movz x7, #0 ; hv const_int val
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    add sp, sp, #112 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_unlink_bb2:
    bl _SYS_DARWIN_UNLINK ; call SYS_DARWIN_UNLINK
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #0] ; hv load L0
    bl __sc1 ; call _sc1
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    add sp, sp, #112 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_mkdir
.private_extern _sys_mkdir
    .p2align 2
_sys_mkdir:
    .loc 1 138 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #128 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797_sys_mkdir_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_mkdir_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_mkdir_bb1 ; branch -> then
__L7797_sys_mkdir_bb1:
    bl _SYS_LINUX_MKDIRAT ; call SYS_LINUX_MKDIRAT
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #99 ; imm 0-15
    mvn x3, x3 ; hv const_int: negate
    ldp x4, x5, [sp, #0] ; hv load L0
    ldp x6, x7, [sp, #16] ; hv load L1
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    add sp, sp, #128 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_mkdir_bb2:
    bl _SYS_DARWIN_MKDIR ; call SYS_DARWIN_MKDIR
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    bl __sc2 ; call _sc2
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    add sp, sp, #128 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_mmap
.private_extern _sys_mmap
    .p2align 2
_sys_mmap:
    .loc 1 146 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #240 ; sp adj
    stp x0, x1, [sp, #48] ; ingress param 0
    stp x2, x3, [sp, #64] ; ingress param 1
    stp x4, x5, [sp, #80] ; ingress param 2
    stp x6, x7, [sp, #96] ; ingress param 3
    ldp x9, x10, [x29, #16] ; ingress stack param 4
    stp x9, x10, [sp, #112] ; store stack param 4
    ldp x9, x10, [x29, #32] ; ingress stack param 5
    stp x9, x10, [sp, #128] ; store stack param 5
__L7797_sys_mmap_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #144] ; hv store L6
    ldp x0, x1, [sp, #144] ; hv load L6
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_mmap_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_mmap_bb1 ; branch -> then
__L7797_sys_mmap_bb1:
    bl _SYS_LINUX_MMAP ; call SYS_LINUX_MMAP
    stp x0, x1, [sp, #176] ; hv store L8
    ldp x0, x1, [sp, #176] ; hv load L8
    ldp x2, x3, [sp, #48] ; hv load L0
    ldp x4, x5, [sp, #64] ; hv load L1
    ldp x6, x7, [sp, #80] ; hv load L2
    ldp x9, x10, [sp, #96] ; hv load L3
    stp x9, x10, [sp, #0] ; C7: stack arg 4
    ldp x9, x10, [sp, #112] ; hv load L4
    stp x9, x10, [sp, #16] ; C7: stack arg 5
    ldp x9, x10, [sp, #128] ; hv load L5
    stp x9, x10, [sp, #32] ; C7: stack arg 6
    bl __sc6 ; call _sc6
    stp x0, x1, [sp, #192] ; hv store L9
    ldp x0, x1, [sp, #192] ; hv load L9
    add sp, sp, #240 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_mmap_bb2:
    bl _SYS_DARWIN_MMAP ; call SYS_DARWIN_MMAP
    stp x0, x1, [sp, #208] ; hv store L10
    ldp x0, x1, [sp, #208] ; hv load L10
    ldp x2, x3, [sp, #48] ; hv load L0
    ldp x4, x5, [sp, #64] ; hv load L1
    ldp x6, x7, [sp, #80] ; hv load L2
    ldp x9, x10, [sp, #96] ; hv load L3
    stp x9, x10, [sp, #0] ; C7: stack arg 4
    ldp x9, x10, [sp, #112] ; hv load L4
    stp x9, x10, [sp, #16] ; C7: stack arg 5
    ldp x9, x10, [sp, #128] ; hv load L5
    stp x9, x10, [sp, #32] ; C7: stack arg 6
    bl __sc6 ; call _sc6
    stp x0, x1, [sp, #224] ; hv store L11
    ldp x0, x1, [sp, #224] ; hv load L11
    add sp, sp, #240 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_munmap
.private_extern _sys_munmap
    .p2align 2
_sys_munmap:
    .loc 1 151 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #128 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797_sys_munmap_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_munmap_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_munmap_bb1 ; branch -> then
__L7797_sys_munmap_bb1:
    bl _SYS_LINUX_MUNMAP ; call SYS_LINUX_MUNMAP
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    bl __sc2 ; call _sc2
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    add sp, sp, #128 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_munmap_bb2:
    bl _SYS_DARWIN_MUNMAP ; call SYS_DARWIN_MUNMAP
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    bl __sc2 ; call _sc2
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    add sp, sp, #128 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_exit
.private_extern _sys_exit
    .p2align 2
_sys_exit:
    .loc 1 156 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #112 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797_sys_exit_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_exit_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_exit_bb1 ; branch -> then
__L7797_sys_exit_bb1:
    bl _SYS_LINUX_EXIT_GROUP ; call SYS_LINUX_EXIT_GROUP
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #0] ; hv load L0
    bl __sc1 ; call _sc1
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    add sp, sp, #112 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_exit_bb2:
    bl _SYS_DARWIN_EXIT ; call SYS_DARWIN_EXIT
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #0] ; hv load L0
    bl __sc1 ; call _sc1
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    add sp, sp, #112 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_getrandom
.private_extern _sys_getrandom
    .p2align 2
_sys_getrandom:
    .loc 1 161 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #240 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L7797_sys_getrandom_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_getrandom_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_getrandom_bb1 ; branch -> then
__L7797_sys_getrandom_bb1:
    bl _SYS_LINUX_GETRANDOM ; call SYS_LINUX_GETRANDOM
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    add sp, sp, #240 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_getrandom_bb2:
    movz x0, #3 ; hv const_str: TAG_STR
    adrp x1, .LCstr0@PAGE ; hv str ptr page
    add x1, x1, .LCstr0@PAGEOFF ; hv str ptr off
    movz x0, #0 ; __hx_str_ptr: TAG_INT
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    movz x4, #0 ; hv const_int: TAG_INT
    movz x5, #0 ; hv const_int val
    bl _sys_open ; call sys_open
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #160] ; hv load L10
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_getrandom_bb4 ; br_cond: !truthy -> else
    b __L7797_sys_getrandom_bb3 ; branch -> then
__L7797_sys_getrandom_bb3:
    ldp x0, x1, [sp, #144] ; hv load L9
    add sp, sp, #240 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_getrandom_bb4:
    ldp x0, x1, [sp, #144] ; hv load L9
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    bl _sys_read ; call sys_read
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #144] ; hv load L9
    bl _sys_close ; call sys_close
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #208] ; hv load L13
    add sp, sp, #240 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_clock_gettime
.private_extern _sys_clock_gettime
    .p2align 2
_sys_clock_gettime:
    .loc 1 171 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #128 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797_sys_clock_gettime_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_clock_gettime_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_clock_gettime_bb1 ; branch -> then
__L7797_sys_clock_gettime_bb1:
    bl _SYS_LINUX_CLOCK_GETTIME ; call SYS_LINUX_CLOCK_GETTIME
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    bl __sc2 ; call _sc2
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    add sp, sp, #128 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_clock_gettime_bb2:
    bl _SYS_DARWIN_CLOCK_GETTIME ; call SYS_DARWIN_CLOCK_GETTIME
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    bl __sc2 ; call _sc2
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    add sp, sp, #128 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_fork
.private_extern _sys_fork
    .p2align 2
_sys_fork:
    .loc 1 183 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #96 ; sp adj
__L7797_sys_fork_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_fork_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_fork_bb1 ; branch -> then
__L7797_sys_fork_bb1:
    bl _SYS_LINUX_FORK ; call SYS_LINUX_FORK
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    bl __sc0 ; call _sc0
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    add sp, sp, #96 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_fork_bb2:
    bl _SYS_DARWIN_FORK ; call SYS_DARWIN_FORK
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    bl __sc0 ; call _sc0
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    add sp, sp, #96 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_execve
.private_extern _sys_execve
    .p2align 2
_sys_execve:
    .loc 1 189 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #144 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L7797_sys_execve_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_execve_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_execve_bb1 ; branch -> then
__L7797_sys_execve_bb1:
    bl _SYS_LINUX_EXECVE ; call SYS_LINUX_EXECVE
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_execve_bb2:
    bl _SYS_DARWIN_EXECVE ; call SYS_DARWIN_EXECVE
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    ldp x6, x7, [sp, #32] ; hv load L2
    bl __sc3 ; call _sc3
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_wait4
.private_extern _sys_wait4
    .p2align 2
_sys_wait4:
    .loc 1 195 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #176 ; sp adj
    stp x0, x1, [sp, #16] ; ingress param 0
    stp x2, x3, [sp, #32] ; ingress param 1
    stp x4, x5, [sp, #48] ; ingress param 2
    stp x6, x7, [sp, #64] ; ingress param 3
__L7797_sys_wait4_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #80] ; hv store L4
    ldp x0, x1, [sp, #80] ; hv load L4
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_wait4_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_wait4_bb1 ; branch -> then
__L7797_sys_wait4_bb1:
    bl _SYS_LINUX_WAIT4 ; call SYS_LINUX_WAIT4
    stp x0, x1, [sp, #112] ; hv store L6
    ldp x0, x1, [sp, #112] ; hv load L6
    ldp x2, x3, [sp, #16] ; hv load L0
    ldp x4, x5, [sp, #32] ; hv load L1
    ldp x6, x7, [sp, #48] ; hv load L2
    ldp x9, x10, [sp, #64] ; hv load L3
    stp x9, x10, [sp, #0] ; C7: stack arg 4
    bl __sc4 ; call _sc4
    stp x0, x1, [sp, #128] ; hv store L7
    ldp x0, x1, [sp, #128] ; hv load L7
    add sp, sp, #176 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_wait4_bb2:
    bl _SYS_DARWIN_WAIT4 ; call SYS_DARWIN_WAIT4
    stp x0, x1, [sp, #144] ; hv store L8
    ldp x0, x1, [sp, #144] ; hv load L8
    ldp x2, x3, [sp, #16] ; hv load L0
    ldp x4, x5, [sp, #32] ; hv load L1
    ldp x6, x7, [sp, #48] ; hv load L2
    ldp x9, x10, [sp, #64] ; hv load L3
    stp x9, x10, [sp, #0] ; C7: stack arg 4
    bl __sc4 ; call _sc4
    stp x0, x1, [sp, #160] ; hv store L9
    ldp x0, x1, [sp, #160] ; hv load L9
    add sp, sp, #176 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_pipe
.private_extern _sys_pipe
    .p2align 2
_sys_pipe:
    .loc 1 204 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #80 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797_sys_pipe_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_pipe_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_pipe_bb1 ; branch -> then
__L7797_sys_pipe_bb1:
    bl _SYS_LINUX_PIPE ; call SYS_LINUX_PIPE
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #0] ; hv load L0
    bl __sc1 ; call _sc1
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    add sp, sp, #80 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_pipe_bb2:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; imm 0-15
    mvn x1, x1 ; hv const_int: negate
    add sp, sp, #80 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_dup2
.private_extern _sys_dup2
    .p2align 2
_sys_dup2:
    .loc 1 212 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #96 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797_sys_dup2_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_dup2_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_dup2_bb1 ; branch -> then
__L7797_sys_dup2_bb1:
    bl _SYS_LINUX_DUP2 ; call SYS_LINUX_DUP2
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    bl __sc2 ; call _sc2
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    add sp, sp, #96 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_dup2_bb2:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; imm 0-15
    mvn x1, x1 ; hv const_int: negate
    add sp, sp, #96 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _sys_nanosleep
.private_extern _sys_nanosleep
    .p2align 2
_sys_nanosleep:
    .loc 1 218 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #128 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797_sys_nanosleep_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_sys_nanosleep_bb2 ; br_cond: !truthy -> else
    b __L7797_sys_nanosleep_bb1 ; branch -> then
__L7797_sys_nanosleep_bb1:
    bl _SYS_LINUX_NANOSLEEP ; call SYS_LINUX_NANOSLEEP
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    bl __sc2 ; call _sc2
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    add sp, sp, #128 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_sys_nanosleep_bb2:
    bl _SYS_DARWIN_NANOSLEEP ; call SYS_DARWIN_NANOSLEEP
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    ldp x2, x3, [sp, #0] ; hv load L0
    ldp x4, x5, [sp, #16] ; hv load L1
    bl __sc2 ; call _sc2
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    add sp, sp, #128 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _O_RDONLY
.private_extern _O_RDONLY
    .p2align 2
_O_RDONLY:
    .loc 1 227 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_O_RDONLY_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _O_WRONLY
.private_extern _O_WRONLY
    .p2align 2
_O_WRONLY:
    .loc 1 228 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_O_WRONLY_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _O_RDWR
.private_extern _O_RDWR
    .p2align 2
_O_RDWR:
    .loc 1 229 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_O_RDWR_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #2 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _O_CREAT_LINUX
.private_extern _O_CREAT_LINUX
    .p2align 2
_O_CREAT_LINUX:
    .loc 1 232 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_O_CREAT_LINUX_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #64 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _O_APPEND_LINUX
.private_extern _O_APPEND_LINUX
    .p2align 2
_O_APPEND_LINUX:
    .loc 1 233 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_O_APPEND_LINUX_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1024 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _O_TRUNC_LINUX
.private_extern _O_TRUNC_LINUX
    .p2align 2
_O_TRUNC_LINUX:
    .loc 1 234 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_O_TRUNC_LINUX_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #512 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _O_CREAT_DARWIN
.private_extern _O_CREAT_DARWIN
    .p2align 2
_O_CREAT_DARWIN:
    .loc 1 235 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_O_CREAT_DARWIN_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #512 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _O_APPEND_DARWIN
.private_extern _O_APPEND_DARWIN
    .p2align 2
_O_APPEND_DARWIN:
    .loc 1 236 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_O_APPEND_DARWIN_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #8 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _O_TRUNC_DARWIN
.private_extern _O_TRUNC_DARWIN
    .p2align 2
_O_TRUNC_DARWIN:
    .loc 1 237 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_O_TRUNC_DARWIN_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1024 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _flag_o_creat
.private_extern _flag_o_creat
    .p2align 2
_flag_o_creat:
    .loc 1 239 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #64 ; sp adj
__L7797_flag_o_creat_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_flag_o_creat_bb2 ; br_cond: !truthy -> else
    b __L7797_flag_o_creat_bb1 ; branch -> then
__L7797_flag_o_creat_bb1:
    bl _O_CREAT_LINUX ; call O_CREAT_LINUX
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_flag_o_creat_bb2:
    bl _O_CREAT_DARWIN ; call O_CREAT_DARWIN
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _flag_o_append
.private_extern _flag_o_append
    .p2align 2
_flag_o_append:
    .loc 1 243 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #64 ; sp adj
__L7797_flag_o_append_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_flag_o_append_bb2 ; br_cond: !truthy -> else
    b __L7797_flag_o_append_bb1 ; branch -> then
__L7797_flag_o_append_bb1:
    bl _O_APPEND_LINUX ; call O_APPEND_LINUX
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_flag_o_append_bb2:
    bl _O_APPEND_DARWIN ; call O_APPEND_DARWIN
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _flag_o_trunc
.private_extern _flag_o_trunc
    .p2align 2
_flag_o_trunc:
    .loc 1 247 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #64 ; sp adj
__L7797_flag_o_trunc_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_flag_o_trunc_bb2 ; br_cond: !truthy -> else
    b __L7797_flag_o_trunc_bb1 ; branch -> then
__L7797_flag_o_trunc_bb1:
    bl _O_TRUNC_LINUX ; call O_TRUNC_LINUX
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_flag_o_trunc_bb2:
    bl _O_TRUNC_DARWIN ; call O_TRUNC_DARWIN
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _PROT_READ
.private_extern _PROT_READ
    .p2align 2
_PROT_READ:
    .loc 1 256 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_PROT_READ_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _PROT_WRITE
.private_extern _PROT_WRITE
    .p2align 2
_PROT_WRITE:
    .loc 1 257 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_PROT_WRITE_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #2 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _PROT_EXEC
.private_extern _PROT_EXEC
    .p2align 2
_PROT_EXEC:
    .loc 1 258 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_PROT_EXEC_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #4 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _MAP_PRIVATE
.private_extern _MAP_PRIVATE
    .p2align 2
_MAP_PRIVATE:
    .loc 1 259 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_MAP_PRIVATE_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #2 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _MAP_ANON_LINUX
.private_extern _MAP_ANON_LINUX
    .p2align 2
_MAP_ANON_LINUX:
    .loc 1 260 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_MAP_ANON_LINUX_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #32 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _MAP_ANON_DARWIN
.private_extern _MAP_ANON_DARWIN
    .p2align 2
_MAP_ANON_DARWIN:
    .loc 1 261 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_MAP_ANON_DARWIN_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #4096 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _flag_map_anon
.private_extern _flag_map_anon
    .p2align 2
_flag_map_anon:
    .loc 1 262 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #64 ; sp adj
__L7797_flag_map_anon_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_flag_map_anon_bb2 ; br_cond: !truthy -> else
    b __L7797_flag_map_anon_bb1 ; branch -> then
__L7797_flag_map_anon_bb1:
    bl _MAP_ANON_LINUX ; call MAP_ANON_LINUX
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_flag_map_anon_bb2:
    bl _MAP_ANON_DARWIN ; call MAP_ANON_DARWIN
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _CLOCK_REALTIME
.private_extern _CLOCK_REALTIME
    .p2align 2
_CLOCK_REALTIME:
    .loc 1 271 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_CLOCK_REALTIME_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _CLOCK_MONOTONIC_LINUX
.private_extern _CLOCK_MONOTONIC_LINUX
    .p2align 2
_CLOCK_MONOTONIC_LINUX:
    .loc 1 272 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_CLOCK_MONOTONIC_LINUX_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _CLOCK_MONOTONIC_DARWIN
.private_extern _CLOCK_MONOTONIC_DARWIN
    .p2align 2
_CLOCK_MONOTONIC_DARWIN:
    .loc 1 273 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_CLOCK_MONOTONIC_DARWIN_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #6 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _clock_monotonic
.private_extern _clock_monotonic
    .p2align 2
_clock_monotonic:
    .loc 1 274 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #64 ; sp adj
__L7797_clock_monotonic_bb0:
    bl _target_is_linux ; call target_is_linux
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_clock_monotonic_bb2 ; br_cond: !truthy -> else
    b __L7797_clock_monotonic_bb1 ; branch -> then
__L7797_clock_monotonic_bb1:
    bl _CLOCK_MONOTONIC_LINUX ; call CLOCK_MONOTONIC_LINUX
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_clock_monotonic_bb2:
    bl _CLOCK_MONOTONIC_DARWIN ; call CLOCK_MONOTONIC_DARWIN
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _HEXA_ARENA_BLOCK_SIZE
.private_extern _HEXA_ARENA_BLOCK_SIZE
    .p2align 2
_HEXA_ARENA_BLOCK_SIZE:
    .loc 1 305 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_HEXA_ARENA_BLOCK_SIZE_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; imm 0-15
    movk x1, #16, lsl #16 ; imm 16-31
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _BLOCK_HDR
.private_extern _BLOCK_HDR
    .p2align 2
_BLOCK_HDR:
    .loc 1 306 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_BLOCK_HDR_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #24 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl ___env_extend
.private_extern ___env_extend
    .p2align 2
___env_extend:
    .loc 1 318 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #160 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797___env_extend_bb0:
    adrp x0, _g2@PAGE ; hv global page
    add x0, x0, _g2@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797___env_extend_bb2 ; br_cond: !truthy -> else
    b __L7797___env_extend_bb1 ; branch -> then
__L7797___env_extend_bb1:
    ldp x0, x1, [sp, #0] ; hv load L0
    adrp x15, _g2@PAGE ; hv global page (store)
    add x15, x15, _g2@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g2
    b __L7797___env_extend_bb5 ; branch
__L7797___env_extend_bb2:
    ldp x0, x1, [sp, #0] ; hv load L0
    adrp x2, _g2@PAGE ; hv global page
    add x2, x2, _g2@PAGEOFF ; hv global off
    ldp x2, x3, [x2] ; hv load global g2
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797___env_extend_bb4 ; br_cond: !truthy -> else
    b __L7797___env_extend_bb3 ; branch -> then
__L7797___env_extend_bb3:
    ldp x0, x1, [sp, #0] ; hv load L0
    adrp x15, _g2@PAGE ; hv global page (store)
    add x15, x15, _g2@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g2
    b __L7797___env_extend_bb4 ; branch
__L7797___env_extend_bb4:
    b __L7797___env_extend_bb5 ; branch
__L7797___env_extend_bb5:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #16] ; hv load L1
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    adrp x2, _g3@PAGE ; hv global page
    add x2, x2, _g3@PAGEOFF ; hv global off
    ldp x2, x3, [x2] ; hv load global g3
    bl _hexa_cmp_gt ; binop >
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797___env_extend_bb7 ; br_cond: !truthy -> else
    b __L7797___env_extend_bb6 ; branch -> then
__L7797___env_extend_bb6:
    ldp x0, x1, [sp, #112] ; hv load L7
    adrp x15, _g3@PAGE ; hv global page (store)
    add x15, x15, _g3@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g3
    b __L7797___env_extend_bb7 ; branch
__L7797___env_extend_bb7:
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #160 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arena_env_lo
.private_extern _hexa_arena_env_lo
    .p2align 2
_hexa_arena_env_lo:
    .loc 1 328 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_hexa_arena_env_lo_bb0:
    adrp x0, _g2@PAGE ; hv global page
    add x0, x0, _g2@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g2
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arena_env_hi
.private_extern _hexa_arena_env_hi
    .p2align 2
_hexa_arena_env_hi:
    .loc 1 329 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_hexa_arena_env_hi_bb0:
    adrp x0, _g3@PAGE ; hv global page
    add x0, x0, _g3@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g3
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _align_up
.private_extern _align_up
    .p2align 2
_align_up:
    .loc 1 331 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #96 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797_align_up_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #16] ; hv load L1
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #16] ; hv load L1
    bl _hexa_div ; binop /
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #16] ; hv load L1
    bl _hexa_mul ; binop *
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    add sp, sp, #96 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl ___blk_next
.private_extern ___blk_next
    .p2align 2
___blk_next:
    .loc 1 336 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #32 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797___blk_next_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    add sp, sp, #32 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl ___blk_cap
.private_extern ___blk_cap
    .p2align 2
___blk_cap:
    .loc 1 337 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #32 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797___blk_cap_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    add sp, sp, #32 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl ___blk_used
.private_extern ___blk_used
    .p2align 2
___blk_used:
    .loc 1 338 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #32 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797___blk_used_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #16 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    add sp, sp, #32 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl ___blk_set_next
.private_extern ___blk_set_next
    .p2align 2
___blk_set_next:
    .loc 1 339 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #48 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797___blk_set_next_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    ldp x4, x5, [sp, #16] ; hv load L1
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #48 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl ___blk_set_cap
.private_extern ___blk_set_cap
    .p2align 2
___blk_set_cap:
    .loc 1 340 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #48 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797___blk_set_cap_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    ldp x4, x5, [sp, #16] ; hv load L1
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #48 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl ___blk_set_used
.private_extern ___blk_set_used
    .p2align 2
___blk_set_used:
    .loc 1 341 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #48 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797___blk_set_used_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #16 ; hv const_int val
    ldp x4, x5, [sp, #16] ; hv load L1
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #48 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arena_new_block
.private_extern _hexa_arena_new_block
    .p2align 2
_hexa_arena_new_block:
    .loc 1 344 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #464 ; sp adj
    stp x0, x1, [sp, #32] ; ingress param 0
__L7797_hexa_arena_new_block_bb0:
    bl _HEXA_ARENA_BLOCK_SIZE ; call HEXA_ARENA_BLOCK_SIZE
    stp x0, x1, [sp, #48] ; hv store L1
    ldp x0, x1, [sp, #48] ; hv load L1
    stp x0, x1, [sp, #64] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L0
    ldp x2, x3, [sp, #64] ; hv load L2
    bl _hexa_cmp_gt ; binop >
    stp x0, x1, [sp, #80] ; hv store L3
    ldp x0, x1, [sp, #80] ; hv load L3
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_new_block_bb2 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_new_block_bb1 ; branch -> then
__L7797_hexa_arena_new_block_bb1:
    ldp x0, x1, [sp, #32] ; hv load L0
    stp x0, x1, [sp, #64] ; hv store L2
    b __L7797_hexa_arena_new_block_bb2 ; branch
__L7797_hexa_arena_new_block_bb2:
    bl _BLOCK_HDR ; call BLOCK_HDR
    stp x0, x1, [sp, #112] ; hv store L5
    ldp x0, x1, [sp, #112] ; hv load L5
    ldp x2, x3, [sp, #64] ; hv load L2
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #128] ; hv store L6
    ldp x0, x1, [sp, #128] ; hv load L6
    stp x0, x1, [sp, #144] ; hv store L7
    bl _MAP_PRIVATE ; call MAP_PRIVATE
    stp x0, x1, [sp, #160] ; hv store L8
    bl _flag_map_anon ; call flag_map_anon
    stp x0, x1, [sp, #176] ; hv store L9
    ldp x0, x1, [sp, #160] ; hv load L8
    ldp x2, x3, [sp, #176] ; hv load L9
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #192] ; hv store L10
    ldp x0, x1, [sp, #192] ; hv load L10
    stp x0, x1, [sp, #208] ; hv store L11
    bl _PROT_READ ; call PROT_READ
    stp x0, x1, [sp, #224] ; hv store L12
    bl _PROT_WRITE ; call PROT_WRITE
    stp x0, x1, [sp, #240] ; hv store L13
    ldp x0, x1, [sp, #224] ; hv load L12
    ldp x2, x3, [sp, #240] ; hv load L13
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #256] ; hv store L14
    ldp x0, x1, [sp, #256] ; hv load L14
    stp x0, x1, [sp, #272] ; hv store L15
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    ldp x2, x3, [sp, #144] ; hv load L7
    ldp x4, x5, [sp, #272] ; hv load L15
    ldp x6, x7, [sp, #208] ; hv load L11
    movz x9, #0 ; hv const_int: TAG_INT
    movz x10, #0 ; imm 0-15
    mvn x10, x10 ; hv const_int: negate
    stp x9, x10, [sp, #0] ; C7: stack arg 4
    movz x9, #0 ; hv const_int: TAG_INT
    movz x10, #0 ; hv const_int val
    stp x9, x10, [sp, #16] ; C7: stack arg 5
    bl _sys_mmap ; call sys_mmap
    stp x0, x1, [sp, #288] ; hv store L16
    ldp x0, x1, [sp, #288] ; hv load L16
    stp x0, x1, [sp, #304] ; hv store L17
    ldp x0, x1, [sp, #304] ; hv load L17
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #320] ; hv store L18
    ldp x0, x1, [sp, #320] ; hv load L18
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_new_block_bb4 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_new_block_bb3 ; branch -> then
__L7797_hexa_arena_new_block_bb3:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #137 ; hv const_int val
    bl _sys_exit ; call sys_exit
    stp x0, x1, [sp, #352] ; hv store L20
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add sp, sp, #464 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_hexa_arena_new_block_bb4:
    ldp x0, x1, [sp, #304] ; hv load L17
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl ___blk_set_next ; call __blk_set_next
    stp x0, x1, [sp, #368] ; hv store L21
    ldp x0, x1, [sp, #304] ; hv load L17
    ldp x2, x3, [sp, #64] ; hv load L2
    bl ___blk_set_cap ; call __blk_set_cap
    stp x0, x1, [sp, #384] ; hv store L22
    ldp x0, x1, [sp, #304] ; hv load L17
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl ___blk_set_used ; call __blk_set_used
    stp x0, x1, [sp, #400] ; hv store L23
    bl _BLOCK_HDR ; call BLOCK_HDR
    stp x0, x1, [sp, #416] ; hv store L24
    ldp x0, x1, [sp, #304] ; hv load L17
    ldp x2, x3, [sp, #416] ; hv load L24
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #432] ; hv store L25
    ldp x0, x1, [sp, #432] ; hv load L25
    ldp x2, x3, [sp, #64] ; hv load L2
    bl ___env_extend ; call __env_extend
    stp x0, x1, [sp, #448] ; hv store L26
    ldp x0, x1, [sp, #304] ; hv load L17
    add sp, sp, #464 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_init
.private_extern _rt_init
    .p2align 2
_rt_init:
    .loc 1 362 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #32 ; sp adj
__L7797_rt_init_bb0:
    bl _HEXA_ARENA_BLOCK_SIZE ; call HEXA_ARENA_BLOCK_SIZE
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_arena_new_block ; call hexa_arena_new_block
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    adrp x15, _g0@PAGE ; hv global page (store)
    add x15, x15, _g0@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g0
    adrp x0, _g0@PAGE ; hv global page
    add x0, x0, _g0@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g0
    adrp x15, _g1@PAGE ; hv global page (store)
    add x15, x15, _g1@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g1
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #32 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arena_on
.private_extern _hexa_arena_on
    .p2align 2
_hexa_arena_on:
    .loc 1 367 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
__L7797_hexa_arena_on_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arena_alloc
.private_extern _hexa_arena_alloc
    .p2align 2
_hexa_arena_alloc:
    .loc 1 375 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #688 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797_hexa_arena_alloc_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    bl _align_up ; call align_up
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_alloc_bb2 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_alloc_bb1 ; branch -> then
__L7797_hexa_arena_alloc_bb1:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #8 ; hv const_int val
    stp x0, x1, [sp, #48] ; hv store L3
    b __L7797_hexa_arena_alloc_bb2 ; branch
__L7797_hexa_arena_alloc_bb2:
    adrp x0, _g0@PAGE ; hv global page
    add x0, x0, _g0@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_alloc_bb4 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_alloc_bb3 ; branch -> then
__L7797_hexa_arena_alloc_bb3:
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_arena_new_block ; call hexa_arena_new_block
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    adrp x15, _g0@PAGE ; hv global page (store)
    add x15, x15, _g0@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g0
    adrp x0, _g0@PAGE ; hv global page
    add x0, x0, _g0@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g0
    adrp x15, _g1@PAGE ; hv global page (store)
    add x15, x15, _g1@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g1
    adrp x0, _g0@PAGE ; hv global page
    add x0, x0, _g0@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_alloc_bb6 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_alloc_bb5 ; branch -> then
__L7797_hexa_arena_alloc_bb4:
    adrp x0, _g1@PAGE ; hv global page
    add x0, x0, _g1@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g1
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    bl ___blk_used ; call __blk_used
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #176] ; hv load L11
    bl ___blk_cap ; call __blk_cap
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #208] ; hv load L13
    ldp x2, x3, [sp, #224] ; hv load L14
    bl _hexa_cmp_gt ; binop >
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_alloc_bb8 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_alloc_bb7 ; branch -> then
__L7797_hexa_arena_alloc_bb5:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add sp, sp, #688 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_hexa_arena_alloc_bb6:
    b __L7797_hexa_arena_alloc_bb4 ; branch
__L7797_hexa_arena_alloc_bb7:
    ldp x0, x1, [sp, #176] ; hv load L11
    bl ___blk_next ; call __blk_next
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #272] ; hv load L17
    stp x0, x1, [sp, #288] ; hv store L18
    b __L7797_hexa_arena_alloc_bb9 ; branch
__L7797_hexa_arena_alloc_bb8:
    bl _BLOCK_HDR ; call BLOCK_HDR
    add x15, sp, #560 ; hv frame base
    stp x0, x1, [x15] ; hv store L35
    ldp x0, x1, [sp, #176] ; hv load L11
    add x15, sp, #560 ; hv frame base
    ldp x2, x3, [x15] ; hv load L35
    bl _hexa_add_slow ; binop +
    add x15, sp, #576 ; hv frame base
    stp x0, x1, [x15] ; hv store L36
    ldp x0, x1, [sp, #176] ; hv load L11
    bl ___blk_used ; call __blk_used
    add x15, sp, #592 ; hv frame base
    stp x0, x1, [x15] ; hv store L37
    add x15, sp, #576 ; hv frame base
    ldp x0, x1, [x15] ; hv load L36
    add x15, sp, #592 ; hv frame base
    ldp x2, x3, [x15] ; hv load L37
    bl _hexa_add_slow ; binop +
    add x15, sp, #608 ; hv frame base
    stp x0, x1, [x15] ; hv store L38
    add x15, sp, #608 ; hv frame base
    ldp x0, x1, [x15] ; hv load L38
    add x15, sp, #624 ; hv frame base
    stp x0, x1, [x15] ; hv store L39
    ldp x0, x1, [sp, #176] ; hv load L11
    bl ___blk_used ; call __blk_used
    add x15, sp, #640 ; hv frame base
    stp x0, x1, [x15] ; hv store L40
    add x15, sp, #640 ; hv frame base
    ldp x0, x1, [x15] ; hv load L40
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_add_slow ; binop +
    add x15, sp, #656 ; hv frame base
    stp x0, x1, [x15] ; hv store L41
    ldp x0, x1, [sp, #176] ; hv load L11
    add x15, sp, #656 ; hv frame base
    ldp x2, x3, [x15] ; hv load L41
    bl ___blk_set_used ; call __blk_set_used
    add x15, sp, #672 ; hv frame base
    stp x0, x1, [x15] ; hv store L42
    add x15, sp, #624 ; hv frame base
    ldp x0, x1, [x15] ; hv load L39
    add sp, sp, #688 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_hexa_arena_alloc_bb9:
    ldp x0, x1, [sp, #288] ; hv load L18
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; ne: eq
    bl _hexa_truthy ; ne: truthy(eq) → w0
    eor x0, x0, #1 ; ne: !truthy
    bl _hexa_bool ; ne: box bool
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #304] ; hv load L19
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_alloc_bb11 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_alloc_bb10 ; branch -> then
__L7797_hexa_arena_alloc_bb10:
    ldp x0, x1, [sp, #288] ; hv load L18
    bl ___blk_cap ; call __blk_cap
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #320] ; hv load L20
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_cmp_ge ; binop >=
    stp x0, x1, [sp, #336] ; hv store L21
    ldp x0, x1, [sp, #336] ; hv load L21
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_alloc_bb13 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_alloc_bb12 ; branch -> then
__L7797_hexa_arena_alloc_bb11:
    ldp x0, x1, [sp, #288] ; hv load L18
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #384] ; hv store L24
    ldp x0, x1, [sp, #384] ; hv load L24
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_alloc_bb15 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_alloc_bb14 ; branch -> then
__L7797_hexa_arena_alloc_bb12:
    b __L7797_hexa_arena_alloc_bb11 ; branch
__L7797_hexa_arena_alloc_bb13:
    ldp x0, x1, [sp, #288] ; hv load L18
    bl ___blk_next ; call __blk_next
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #368] ; hv load L23
    stp x0, x1, [sp, #288] ; hv store L18
    b __L7797_hexa_arena_alloc_bb9 ; branch
__L7797_hexa_arena_alloc_bb14:
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_arena_new_block ; call hexa_arena_new_block
    stp x0, x1, [sp, #416] ; hv store L26
    ldp x0, x1, [sp, #416] ; hv load L26
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #288] ; hv load L18
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #432] ; hv store L27
    ldp x0, x1, [sp, #432] ; hv load L27
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_alloc_bb17 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_alloc_bb16 ; branch -> then
__L7797_hexa_arena_alloc_bb15:
    ldp x0, x1, [sp, #288] ; hv load L18
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl ___blk_set_used ; call __blk_set_used
    add x15, sp, #544 ; hv frame base
    stp x0, x1, [x15] ; hv store L34
    ldp x0, x1, [sp, #288] ; hv load L18
    adrp x15, _g1@PAGE ; hv global page (store)
    add x15, x15, _g1@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g1
    ldp x0, x1, [sp, #288] ; hv load L18
    stp x0, x1, [sp, #176] ; hv store L11
    b __L7797_hexa_arena_alloc_bb8 ; branch
__L7797_hexa_arena_alloc_bb16:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add sp, sp, #688 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_hexa_arena_alloc_bb17:
    adrp x0, _g1@PAGE ; hv global page
    add x0, x0, _g1@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g1
    stp x0, x1, [sp, #464] ; hv store L29
    b __L7797_hexa_arena_alloc_bb18 ; branch
__L7797_hexa_arena_alloc_bb18:
    ldp x0, x1, [sp, #464] ; hv load L29
    bl ___blk_next ; call __blk_next
    stp x0, x1, [sp, #480] ; hv store L30
    ldp x0, x1, [sp, #480] ; hv load L30
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; ne: eq
    bl _hexa_truthy ; ne: truthy(eq) → w0
    eor x0, x0, #1 ; ne: !truthy
    bl _hexa_bool ; ne: box bool
    stp x0, x1, [sp, #496] ; hv store L31
    ldp x0, x1, [sp, #496] ; hv load L31
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_alloc_bb20 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_alloc_bb19 ; branch -> then
__L7797_hexa_arena_alloc_bb19:
    ldp x0, x1, [sp, #464] ; hv load L29
    bl ___blk_next ; call __blk_next
    add x15, sp, #512 ; hv frame base
    stp x0, x1, [x15] ; hv store L32
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    stp x0, x1, [sp, #464] ; hv store L29
    b __L7797_hexa_arena_alloc_bb18 ; branch
__L7797_hexa_arena_alloc_bb20:
    ldp x0, x1, [sp, #464] ; hv load L29
    ldp x2, x3, [sp, #288] ; hv load L18
    bl ___blk_set_next ; call __blk_set_next
    add x15, sp, #528 ; hv frame base
    stp x0, x1, [x15] ; hv store L33
    b __L7797_hexa_arena_alloc_bb15 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #688 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arena_mark
.private_extern _hexa_arena_mark
    .p2align 2
_hexa_arena_mark:
    .loc 1 409 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #80 ; sp adj
__L7797_hexa_arena_mark_bb0:
    adrp x0, _g1@PAGE ; hv global page
    add x0, x0, _g1@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_mark_bb2 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_mark_bb1 ; branch -> then
__L7797_hexa_arena_mark_bb1:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    mov x0, x1 ; __hx_make_val: lo = tag word
    mov x1, x3 ; __hx_make_val: hi = payload word
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #80 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_hexa_arena_mark_bb2:
    adrp x0, _g1@PAGE ; hv global page
    add x0, x0, _g1@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g1
    bl ___blk_used ; call __blk_used
    stp x0, x1, [sp, #48] ; hv store L3
    adrp x0, _g1@PAGE ; hv global page
    add x0, x0, _g1@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g1
    ldp x2, x3, [sp, #48] ; hv load L3
    mov x0, x1 ; __hx_make_val: lo = tag word
    mov x1, x3 ; __hx_make_val: hi = payload word
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    add sp, sp, #80 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arena_rewind
.private_extern _hexa_arena_rewind
    .p2align 2
_hexa_arena_rewind:
    .loc 1 415 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #256 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797_hexa_arena_rewind_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    mov x1, x0 ; __hx_tag: payload = v.tag
    movz x0, #0 ; __hx_tag: TAG_INT
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_rewind_bb2 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_rewind_bb1 ; branch -> then
__L7797_hexa_arena_rewind_bb1:
    adrp x0, _g0@PAGE ; hv global page
    add x0, x0, _g0@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; ne: eq
    bl _hexa_truthy ; ne: truthy(eq) → w0
    eor x0, x0, #1 ; ne: !truthy
    bl _hexa_bool ; ne: box bool
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_rewind_bb4 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_rewind_bb3 ; branch -> then
__L7797_hexa_arena_rewind_bb2:
    ldp x0, x1, [sp, #32] ; hv load L2
    ldp x2, x3, [sp, #64] ; hv load L4
    bl ___blk_set_used ; call __blk_set_used
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #32] ; hv load L2
    bl ___blk_next ; call __blk_next
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    stp x0, x1, [sp, #192] ; hv store L12
    b __L7797_hexa_arena_rewind_bb5 ; branch
__L7797_hexa_arena_rewind_bb3:
    adrp x0, _g0@PAGE ; hv global page
    add x0, x0, _g0@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl ___blk_set_used ; call __blk_set_used
    stp x0, x1, [sp, #144] ; hv store L9
    adrp x0, _g0@PAGE ; hv global page
    add x0, x0, _g0@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g0
    adrp x15, _g1@PAGE ; hv global page (store)
    add x15, x15, _g1@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g1
    b __L7797_hexa_arena_rewind_bb4 ; branch
__L7797_hexa_arena_rewind_bb4:
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #256 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_hexa_arena_rewind_bb5:
    ldp x0, x1, [sp, #192] ; hv load L12
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; ne: eq
    bl _hexa_truthy ; ne: truthy(eq) → w0
    eor x0, x0, #1 ; ne: !truthy
    bl _hexa_bool ; ne: box bool
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #208] ; hv load L13
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_rewind_bb7 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_rewind_bb6 ; branch -> then
__L7797_hexa_arena_rewind_bb6:
    ldp x0, x1, [sp, #192] ; hv load L12
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl ___blk_set_used ; call __blk_set_used
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #192] ; hv load L12
    bl ___blk_next ; call __blk_next
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    stp x0, x1, [sp, #192] ; hv store L12
    b __L7797_hexa_arena_rewind_bb5 ; branch
__L7797_hexa_arena_rewind_bb7:
    ldp x0, x1, [sp, #32] ; hv load L2
    adrp x15, _g1@PAGE ; hv global page (store)
    add x15, x15, _g1@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g1
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #256 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arena_reset
.private_extern _hexa_arena_reset
    .p2align 2
_hexa_arena_reset:
    .loc 1 434 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #96 ; sp adj
__L7797_hexa_arena_reset_bb0:
    adrp x0, _g0@PAGE ; hv global page
    add x0, x0, _g0@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_reset_bb2 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_reset_bb1 ; branch -> then
__L7797_hexa_arena_reset_bb1:
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #96 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L7797_hexa_arena_reset_bb2:
    adrp x0, _g0@PAGE ; hv global page
    add x0, x0, _g0@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g0
    stp x0, x1, [sp, #32] ; hv store L2
    b __L7797_hexa_arena_reset_bb3 ; branch
__L7797_hexa_arena_reset_bb3:
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; ne: eq
    bl _hexa_truthy ; ne: truthy(eq) → w0
    eor x0, x0, #1 ; ne: !truthy
    bl _hexa_bool ; ne: box bool
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L7797_hexa_arena_reset_bb5 ; br_cond: !truthy -> else
    b __L7797_hexa_arena_reset_bb4 ; branch -> then
__L7797_hexa_arena_reset_bb4:
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl ___blk_set_used ; call __blk_set_used
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #32] ; hv load L2
    bl ___blk_next ; call __blk_next
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    stp x0, x1, [sp, #32] ; hv store L2
    b __L7797_hexa_arena_reset_bb3 ; branch
__L7797_hexa_arena_reset_bb5:
    adrp x0, _g0@PAGE ; hv global page
    add x0, x0, _g0@PAGEOFF ; hv global off
    ldp x0, x1, [x0] ; hv load global g0
    adrp x15, _g1@PAGE ; hv global page (store)
    add x15, x15, _g1@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g1
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #96 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_ptr_alloc
.private_extern _hexa_ptr_alloc
    .p2align 2
_hexa_ptr_alloc:
    .loc 1 447 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #32 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L7797_hexa_ptr_alloc_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_arena_alloc ; call hexa_arena_alloc
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    add sp, sp, #32 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_ptr_free
.private_extern _hexa_ptr_free
    .p2align 2
_hexa_ptr_free:
    .loc 1 451 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #32 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797_hexa_ptr_free_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add sp, sp, #32 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_ptr_write_byte
.private_extern _hexa_ptr_write_byte
    .p2align 2
_hexa_ptr_write_byte:
    .loc 1 456 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #64 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L7797_hexa_ptr_write_byte_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #16] ; hv load L1
    ldp x4, x5, [sp, #32] ; hv load L2
    add x1, x1, x3 ; __hx_ptr_store8: addr = ptr + off
    strb w5, [x1] ; __hx_ptr_store8: *(u8*)addr = val
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x0, #0 ; __hx_ptr_store8: TAG_INT
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_ptr_read_byte
.private_extern _hexa_ptr_read_byte
    .p2align 2
_hexa_ptr_read_byte:
    .loc 1 461 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #48 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797_hexa_ptr_read_byte_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #16] ; hv load L1
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #48 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_ptr_write_64
.private_extern _hexa_ptr_write_64
    .p2align 2
_hexa_ptr_write_64:
    .loc 1 465 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #64 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L7797_hexa_ptr_write_64_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #16] ; hv load L1
    ldp x4, x5, [sp, #32] ; hv load L2
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_ptr_read_64
.private_extern _hexa_ptr_read_64
    .p2align 2
_hexa_ptr_read_64:
    .loc 1 470 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #48 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L7797_hexa_ptr_read_64_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #16] ; hv load L1
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #48 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _main
    .p2align 2
_main:
    .loc 1 308 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    bl _hexa_set_args ; entry: wire argc/argv -> hexa_set_args
    sub sp, sp, #64 ; sp adj
__L7797_main_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    adrp x15, _g0@PAGE ; hv global page (store)
    add x15, x15, _g0@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g0
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    adrp x15, _g1@PAGE ; hv global page (store)
    add x15, x15, _g1@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g1
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    adrp x15, _g2@PAGE ; hv global page (store)
    add x15, x15, _g2@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g2
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    adrp x15, _g3@PAGE ; hv global page (store)
    add x15, x15, _g3@PAGEOFF ; hv global off (store)
    stp x0, x1, [x15] ; hv store global g3
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.section __TEXT,__const
.LCstr0:
    .byte 0x2f, 0x64, 0x65, 0x76, 0x2f, 0x75, 0x72, 0x61, 0x6e, 0x64, 0x6f, 0x6d, 0x00
.section __DATA,__data
    .p2align 3
_g0:
    .quad 0
    .quad 0
    .p2align 3
_g1:
    .quad 0
    .quad 0
    .p2align 3
_g2:
    .quad 0
    .quad 0
    .p2align 3
_g3:
    .quad 0
    .quad 0
.section __HEXA,__cap
_hexa_cap_manifest:
.section __HEXA,__abi
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
