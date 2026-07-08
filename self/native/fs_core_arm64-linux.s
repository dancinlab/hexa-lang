// fs_core_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B FS-R1 write-half).
// GENERATED: tool/regen_fs_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o fs_core_arm64-linux.s stdlib/runtime/fs_write_core.hexa.
//   Provides the FS-core WRITE-half (fs_write_all_native = open(O_WRONLY|
//   O_CREAT|O_TRUNC,0644)+write+close; fs_append_all_native = O_APPEND) as
//   native syscall bodies over the leaf intrinsics __hx_syscall6 /
//   __hx_target_os / __hx_target_arch (lowered inline). SELF-CONTAINED — no
//   external .globl (the per-target syscall numbers + open flags are inlined),
//   so NO clash with the alloc seed`s syscall surface. These intrinsics are
//   gen2-native-only (hexat C-transpile cannot lower them), so the bodies enter
//   the shipped runtime.a ONLY via this seed.
//   ABI: ELF aarch64, fs_*_all_native no underscore.
//   Lets stage_resolve_runtime_a define HEXA_RT_FS_NATIVE + ar this .o into
//   runtime.a so rt_write_bytes / rt_write_bytes_append delegate to it.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/fs_write_core.hexa
.file 1 "stdlib/runtime/fs_write_core.hexa"
.text
.globl _fsw_is_linux
.hidden _fsw_is_linux
    .p2align 2
_fsw_is_linux:
    .loc 1 42 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #32 // sp adj
_L1acd__fsw_is_linux_bb0:
    movz x1, #0 // __hx_target_os: 0 = linux
    movz x0, #0 // __hx_target_os: TAG_INT
    stp x0, x1, [sp, #0] // hv store L0
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    add sp, sp, #32 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _fsw_is_arm64
.hidden _fsw_is_arm64
    .p2align 2
_fsw_is_arm64:
    .loc 1 43 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #32 // sp adj
_L1acd__fsw_is_arm64_bb0:
    movz x1, #1 // __hx_target_arch: 1 = arm64
    movz x0, #0 // __hx_target_arch: TAG_INT
    stp x0, x1, [sp, #0] // hv store L0
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    add sp, sp, #32 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _fsw_sc3
.hidden _fsw_sc3
    .p2align 2
_fsw_sc3:
    .loc 1 45 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #128 // sp adj
    stp x0, x1, [sp, #48] // ingress param 0
    stp x2, x3, [sp, #64] // ingress param 1
    stp x4, x5, [sp, #80] // ingress param 2
    stp x6, x7, [sp, #96] // ingress param 3
_L1acd__fsw_sc3_bb0:
    ldp x7, x8, [sp, #64] // hv load L1
    mov x9, x8 // __hx_syscall6: stage arg
    ldp x7, x8, [sp, #80] // hv load L2
    mov x10, x8 // __hx_syscall6: stage arg
    ldp x7, x8, [sp, #96] // hv load L3
    mov x11, x8 // __hx_syscall6: stage arg
    movz x7, #0 // hv const_int: TAG_INT
    movz x8, #0 // hv const_int val
    mov x12, x8 // __hx_syscall6: stage arg
    movz x7, #0 // hv const_int: TAG_INT
    movz x8, #0 // hv const_int val
    mov x13, x8 // __hx_syscall6: stage arg
    movz x7, #0 // hv const_int: TAG_INT
    movz x8, #0 // hv const_int val
    mov x14, x8 // __hx_syscall6: stage arg
    ldp x7, x8, [sp, #48] // hv load L0
    mov x15, x8 // __hx_syscall6: stage syscall num
    mov x0, x9 // __hx_syscall6: arg -> x0
    mov x1, x10 // __hx_syscall6: arg -> x1
    mov x2, x11 // __hx_syscall6: arg -> x2
    mov x3, x12 // __hx_syscall6: arg -> x3
    mov x4, x13 // __hx_syscall6: arg -> x4
    mov x5, x14 // __hx_syscall6: arg -> x5
    mov x8, x15 // __hx_syscall6: x8 = syscall num
    svc #0 // __hx_syscall6: Linux syscall trap
    mov x1, x0 // __hx_syscall6: payload = result
    movz x0, #0 // __hx_syscall6: TAG_INT
    stp x0, x1, [sp, #112] // hv store L4
    ldp x0, x1, [sp, #112] // hv load L4
    add sp, sp, #128 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _fsw_sc1
.hidden _fsw_sc1
    .p2align 2
_fsw_sc1:
    .loc 1 46 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #96 // sp adj
    stp x0, x1, [sp, #48] // ingress param 0
    stp x2, x3, [sp, #64] // ingress param 1
_L1acd__fsw_sc1_bb0:
    ldp x7, x8, [sp, #64] // hv load L1
    mov x9, x8 // __hx_syscall6: stage arg
    movz x7, #0 // hv const_int: TAG_INT
    movz x8, #0 // hv const_int val
    mov x10, x8 // __hx_syscall6: stage arg
    movz x7, #0 // hv const_int: TAG_INT
    movz x8, #0 // hv const_int val
    mov x11, x8 // __hx_syscall6: stage arg
    movz x7, #0 // hv const_int: TAG_INT
    movz x8, #0 // hv const_int val
    mov x12, x8 // __hx_syscall6: stage arg
    movz x7, #0 // hv const_int: TAG_INT
    movz x8, #0 // hv const_int val
    mov x13, x8 // __hx_syscall6: stage arg
    movz x7, #0 // hv const_int: TAG_INT
    movz x8, #0 // hv const_int val
    mov x14, x8 // __hx_syscall6: stage arg
    ldp x7, x8, [sp, #48] // hv load L0
    mov x15, x8 // __hx_syscall6: stage syscall num
    mov x0, x9 // __hx_syscall6: arg -> x0
    mov x1, x10 // __hx_syscall6: arg -> x1
    mov x2, x11 // __hx_syscall6: arg -> x2
    mov x3, x12 // __hx_syscall6: arg -> x3
    mov x4, x13 // __hx_syscall6: arg -> x4
    mov x5, x14 // __hx_syscall6: arg -> x5
    mov x8, x15 // __hx_syscall6: x8 = syscall num
    svc #0 // __hx_syscall6: Linux syscall trap
    mov x1, x0 // __hx_syscall6: payload = result
    movz x0, #0 // __hx_syscall6: TAG_INT
    stp x0, x1, [sp, #80] // hv store L2
    ldp x0, x1, [sp, #80] // hv load L2
    add sp, sp, #96 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_LINUX_WRITE
.hidden _FSW_LINUX_WRITE
    .p2align 2
_FSW_LINUX_WRITE:
    .loc 1 49 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_LINUX_WRITE_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_LINUX_OPEN
.hidden _FSW_LINUX_OPEN
    .p2align 2
_FSW_LINUX_OPEN:
    .loc 1 50 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_LINUX_OPEN_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_LINUX_CLOSE
.hidden _FSW_LINUX_CLOSE
    .p2align 2
_FSW_LINUX_CLOSE:
    .loc 1 51 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_LINUX_CLOSE_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #3 // hv const_int val
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_DARWIN_WRITE
.hidden _FSW_DARWIN_WRITE
    .p2align 2
_FSW_DARWIN_WRITE:
    .loc 1 53 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_DARWIN_WRITE_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // imm 0-15
    movk x1, #512, lsl #16 // imm 16-31
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_DARWIN_OPEN
.hidden _FSW_DARWIN_OPEN
    .p2align 2
_FSW_DARWIN_OPEN:
    .loc 1 54 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_DARWIN_OPEN_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #5 // imm 0-15
    movk x1, #512, lsl #16 // imm 16-31
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_DARWIN_CLOSE
.hidden _FSW_DARWIN_CLOSE
    .p2align 2
_FSW_DARWIN_CLOSE:
    .loc 1 55 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_DARWIN_CLOSE_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #6 // imm 0-15
    movk x1, #512, lsl #16 // imm 16-31
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_O_WRONLY
.hidden _FSW_O_WRONLY
    .p2align 2
_FSW_O_WRONLY:
    .loc 1 58 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_O_WRONLY_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_O_CREAT_LINUX
.hidden _FSW_O_CREAT_LINUX
    .p2align 2
_FSW_O_CREAT_LINUX:
    .loc 1 59 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_O_CREAT_LINUX_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #64 // hv const_int val
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_O_TRUNC_LINUX
.hidden _FSW_O_TRUNC_LINUX
    .p2align 2
_FSW_O_TRUNC_LINUX:
    .loc 1 60 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_O_TRUNC_LINUX_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #512 // hv const_int val
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_O_APPEND_LINUX
.hidden _FSW_O_APPEND_LINUX
    .p2align 2
_FSW_O_APPEND_LINUX:
    .loc 1 61 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_O_APPEND_LINUX_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1024 // hv const_int val
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_O_CREAT_DARWIN
.hidden _FSW_O_CREAT_DARWIN
    .p2align 2
_FSW_O_CREAT_DARWIN:
    .loc 1 62 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_O_CREAT_DARWIN_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #512 // hv const_int val
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_O_TRUNC_DARWIN
.hidden _FSW_O_TRUNC_DARWIN
    .p2align 2
_FSW_O_TRUNC_DARWIN:
    .loc 1 63 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_O_TRUNC_DARWIN_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1024 // hv const_int val
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _FSW_O_APPEND_DARWIN
.hidden _FSW_O_APPEND_DARWIN
    .p2align 2
_FSW_O_APPEND_DARWIN:
    .loc 1 64 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_L1acd__FSW_O_APPEND_DARWIN_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #8 // hv const_int val
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _fsw_open
.hidden _fsw_open
    .p2align 2
_fsw_open:
    .loc 1 66 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #144 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_L1acd__fsw_open_bb0:
    bl _fsw_is_linux // call _fsw_is_linux
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd__fsw_open_bb2 // br_cond: !truthy -> else
    b _L1acd__fsw_open_bb1 // branch -> then
_L1acd__fsw_open_bb1:
    bl _FSW_LINUX_OPEN // call _FSW_LINUX_OPEN
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #0] // hv load L0
    ldp x4, x5, [sp, #16] // hv load L1
    ldp x6, x7, [sp, #32] // hv load L2
    bl _fsw_sc3 // call _fsw_sc3
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L1acd__fsw_open_bb2:
    bl _FSW_DARWIN_OPEN // call _FSW_DARWIN_OPEN
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #0] // hv load L0
    ldp x4, x5, [sp, #16] // hv load L1
    ldp x6, x7, [sp, #32] // hv load L2
    bl _fsw_sc3 // call _fsw_sc3
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _fsw_write
.hidden _fsw_write
    .p2align 2
_fsw_write:
    .loc 1 70 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #144 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_L1acd__fsw_write_bb0:
    bl _fsw_is_linux // call _fsw_is_linux
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd__fsw_write_bb2 // br_cond: !truthy -> else
    b _L1acd__fsw_write_bb1 // branch -> then
_L1acd__fsw_write_bb1:
    bl _FSW_LINUX_WRITE // call _FSW_LINUX_WRITE
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #0] // hv load L0
    ldp x4, x5, [sp, #16] // hv load L1
    ldp x6, x7, [sp, #32] // hv load L2
    bl _fsw_sc3 // call _fsw_sc3
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L1acd__fsw_write_bb2:
    bl _FSW_DARWIN_WRITE // call _FSW_DARWIN_WRITE
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #0] // hv load L0
    ldp x4, x5, [sp, #16] // hv load L1
    ldp x6, x7, [sp, #32] // hv load L2
    bl _fsw_sc3 // call _fsw_sc3
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _fsw_close
.hidden _fsw_close
    .p2align 2
_fsw_close:
    .loc 1 74 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #112 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L1acd__fsw_close_bb0:
    bl _fsw_is_linux // call _fsw_is_linux
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd__fsw_close_bb2 // br_cond: !truthy -> else
    b _L1acd__fsw_close_bb1 // branch -> then
_L1acd__fsw_close_bb1:
    bl _FSW_LINUX_CLOSE // call _FSW_LINUX_CLOSE
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #0] // hv load L0
    bl _fsw_sc1 // call _fsw_sc1
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L1acd__fsw_close_bb2:
    bl _FSW_DARWIN_CLOSE // call _FSW_DARWIN_CLOSE
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #0] // hv load L0
    bl _fsw_sc1 // call _fsw_sc1
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fs_write_all_native
.hidden fs_write_all_native
    .p2align 2
fs_write_all_native:
    .loc 1 83 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #512 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_L1acd_fs_write_all_native_bb0:
    bl _FSW_O_WRONLY // call _FSW_O_WRONLY
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    bl _fsw_is_linux // call _fsw_is_linux
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd_fs_write_all_native_bb2 // br_cond: !truthy -> else
    b _L1acd_fs_write_all_native_bb1 // branch -> then
_L1acd_fs_write_all_native_bb1:
    bl _FSW_O_CREAT_LINUX // call _FSW_O_CREAT_LINUX
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #128] // hv store L8
    bl _FSW_O_TRUNC_LINUX // call _FSW_O_TRUNC_LINUX
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #128] // hv load L8
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #64] // hv store L4
    b _L1acd_fs_write_all_native_bb3 // branch
_L1acd_fs_write_all_native_bb2:
    bl _FSW_O_CREAT_DARWIN // call _FSW_O_CREAT_DARWIN
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #192] // hv store L12
    bl _FSW_O_TRUNC_DARWIN // call _FSW_O_TRUNC_DARWIN
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #64] // hv store L4
    b _L1acd_fs_write_all_native_bb3 // branch
_L1acd_fs_write_all_native_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L4
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #420 // hv const_int val
    bl _fsw_open // call _fsw_open
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd_fs_write_all_native_bb5 // br_cond: !truthy -> else
    b _L1acd_fs_write_all_native_bb4 // branch -> then
_L1acd_fs_write_all_native_bb4:
    ldp x0, x1, [sp, #256] // hv load L16
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L1acd_fs_write_all_native_bb5:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #304] // hv store L19
    b _L1acd_fs_write_all_native_bb6 // branch
_L1acd_fs_write_all_native_bb6:
    ldp x0, x1, [sp, #304] // hv load L19
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd_fs_write_all_native_bb8 // br_cond: !truthy -> else
    b _L1acd_fs_write_all_native_bb7 // branch -> then
_L1acd_fs_write_all_native_bb7:
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #304] // hv load L19
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #304] // hv load L19
    bl hexa_sub // binop -
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #256] // hv load L16
    ldp x2, x3, [sp, #336] // hv load L21
    ldp x4, x5, [sp, #352] // hv load L22
    bl _fsw_write // call _fsw_write
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd_fs_write_all_native_bb10 // br_cond: !truthy -> else
    b _L1acd_fs_write_all_native_bb9 // branch -> then
_L1acd_fs_write_all_native_bb8:
    ldp x0, x1, [sp, #256] // hv load L16
    bl _fsw_close // call _fsw_close
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L1acd_fs_write_all_native_bb9:
    ldp x0, x1, [sp, #256] // hv load L16
    bl _fsw_close // call _fsw_close
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd_fs_write_all_native_bb12 // br_cond: !truthy -> else
    b _L1acd_fs_write_all_native_bb11 // branch -> then
_L1acd_fs_write_all_native_bb10:
    ldp x0, x1, [sp, #304] // hv load L19
    ldp x2, x3, [sp, #384] // hv load L24
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #304] // hv store L19
    b _L1acd_fs_write_all_native_bb6 // branch
_L1acd_fs_write_all_native_bb11:
    ldp x0, x1, [sp, #384] // hv load L24
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L1acd_fs_write_all_native_bb12:
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fs_append_all_native
.hidden fs_append_all_native
    .p2align 2
fs_append_all_native:
    .loc 1 108 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #512 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_L1acd_fs_append_all_native_bb0:
    bl _FSW_O_WRONLY // call _FSW_O_WRONLY
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    bl _fsw_is_linux // call _fsw_is_linux
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd_fs_append_all_native_bb2 // br_cond: !truthy -> else
    b _L1acd_fs_append_all_native_bb1 // branch -> then
_L1acd_fs_append_all_native_bb1:
    bl _FSW_O_CREAT_LINUX // call _FSW_O_CREAT_LINUX
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #128] // hv store L8
    bl _FSW_O_APPEND_LINUX // call _FSW_O_APPEND_LINUX
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #128] // hv load L8
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #64] // hv store L4
    b _L1acd_fs_append_all_native_bb3 // branch
_L1acd_fs_append_all_native_bb2:
    bl _FSW_O_CREAT_DARWIN // call _FSW_O_CREAT_DARWIN
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #192] // hv store L12
    bl _FSW_O_APPEND_DARWIN // call _FSW_O_APPEND_DARWIN
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #64] // hv store L4
    b _L1acd_fs_append_all_native_bb3 // branch
_L1acd_fs_append_all_native_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L4
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #420 // hv const_int val
    bl _fsw_open // call _fsw_open
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd_fs_append_all_native_bb5 // br_cond: !truthy -> else
    b _L1acd_fs_append_all_native_bb4 // branch -> then
_L1acd_fs_append_all_native_bb4:
    ldp x0, x1, [sp, #256] // hv load L16
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L1acd_fs_append_all_native_bb5:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #304] // hv store L19
    b _L1acd_fs_append_all_native_bb6 // branch
_L1acd_fs_append_all_native_bb6:
    ldp x0, x1, [sp, #304] // hv load L19
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd_fs_append_all_native_bb8 // br_cond: !truthy -> else
    b _L1acd_fs_append_all_native_bb7 // branch -> then
_L1acd_fs_append_all_native_bb7:
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #304] // hv load L19
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #304] // hv load L19
    bl hexa_sub // binop -
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #256] // hv load L16
    ldp x2, x3, [sp, #336] // hv load L21
    ldp x4, x5, [sp, #352] // hv load L22
    bl _fsw_write // call _fsw_write
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd_fs_append_all_native_bb10 // br_cond: !truthy -> else
    b _L1acd_fs_append_all_native_bb9 // branch -> then
_L1acd_fs_append_all_native_bb8:
    ldp x0, x1, [sp, #256] // hv load L16
    bl _fsw_close // call _fsw_close
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L1acd_fs_append_all_native_bb9:
    ldp x0, x1, [sp, #256] // hv load L16
    bl _fsw_close // call _fsw_close
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L1acd_fs_append_all_native_bb12 // br_cond: !truthy -> else
    b _L1acd_fs_append_all_native_bb11 // branch -> then
_L1acd_fs_append_all_native_bb10:
    ldp x0, x1, [sp, #304] // hv load L19
    ldp x2, x3, [sp, #384] // hv load L24
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #304] // hv store L19
    b _L1acd_fs_append_all_native_bb6 // branch
_L1acd_fs_append_all_native_bb11:
    ldp x0, x1, [sp, #384] // hv load L24
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L1acd_fs_append_all_native_bb12:
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

.section .note.GNU-stack,"",%progbits
