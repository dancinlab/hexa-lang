// num_core_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM — sh-num-native).
// GENERATED: tool/regen_num_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o num_core_x86_64.s stdlib/runtime/num_core.hexa.
//   Provides the num-core parse half (rt_parse_int_native) as a native
//   raw-mem body (__hx_ptr_load8 byte scan + digit fold + strtoll-faithful
//   overflow clamp, byte-faithful to the C hxlcl_strtoll(cs,NULL,base)). These
//   intrinsics are gen2-native-only (the hexat C-transpile bootstrap cannot
//   lower them), so the body enters the shipped runtime.a ONLY via this seed —
//   the array/str_core mechanism (resolve_native_num_core_seed).
//   ABI: ELF, rt_parse_int_native no underscore. External: NONE (fully self-contained).
//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_INT_NATIVE + ar this
//   .o into runtime.a so hexa_as_num delegates its string→int path to native.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/summer/dancinlab/hexa-lang/stdlib/runtime/num_core.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/num_core.hexa"
.text
.globl rt_parse_int_native
.hidden rt_parse_int_native
    .p2align 4
rt_parse_int_native:
    .loc 1 78 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 2000 # prologue: alloc spill frame
    mov [rbp - 1032], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.Ldd24_rt_parse_int_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1040], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 1040] # tag L1 from tag-slot
    mov [rbp - 1048], r11 # store tag L2
    mov r14, 0 # assign L3
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1056], r11 # store tag L3
    mov r15, 1 # assign L4
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1064], r11 # store tag L4
    jmp .Ldd24_rt_parse_int_native_bb1 # branch
.Ldd24_rt_parse_int_native_bb1:
    mov r11, 0 # hv payload
    mov r10, r15 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1072], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb3 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb2 # jump -> then
.Ldd24_rt_parse_int_native_bb2:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1080], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 1080] # tag L6 from tag-slot
    mov [rbp - 1088], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    mov r11, 32 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1096], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 1096] # tag L8 from tag-slot
    mov [rbp - 1104], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r11, r11 # hv payload
    mov r10, 8 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1112], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 1112] # tag L10 from tag-slot
    mov [rbp - 1120], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 14 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1128], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 1128] # tag L12 from tag-slot
    mov [rbp - 1136], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1144], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 1144] # tag L14 from tag-slot
    mov [rbp - 1152], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1160], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 1160] # tag L16 from tag-slot
    mov [rbp - 1168], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1176], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb5 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb4 # jump -> then
.Ldd24_rt_parse_int_native_bb3:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1200], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 1200] # tag L21 from tag-slot
    mov [rbp - 1208], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, 0 # assign L23
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1216], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    mov r11, 43 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1224], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb8 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb7 # jump -> then
.Ldd24_rt_parse_int_native_bb4:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1192], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1192] # tag L20 from tag-slot
    mov [rbp - 1056], r11 # store tag L3
    jmp .Ldd24_rt_parse_int_native_bb6 # branch
.Ldd24_rt_parse_int_native_bb5:
    mov r15, 0 # assign L4
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1064], r11 # store tag L4
    jmp .Ldd24_rt_parse_int_native_bb6 # branch
.Ldd24_rt_parse_int_native_bb6:
    jmp .Ldd24_rt_parse_int_native_bb1 # branch
.Ldd24_rt_parse_int_native_bb7:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1240], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1240] # tag L26 from tag-slot
    mov [rbp - 1056], r11 # store tag L3
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1248], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 1248] # tag L27 from tag-slot
    mov [rbp - 1208], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    jmp .Ldd24_rt_parse_int_native_bb11 # branch
.Ldd24_rt_parse_int_native_bb8:
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    mov r11, 45 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1256], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb10 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb9 # jump -> then
.Ldd24_rt_parse_int_native_bb9:
    mov r10, 1 # assign L23
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1216], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1272], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1272] # tag L30 from tag-slot
    mov [rbp - 1056], r11 # store tag L3
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1280], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 1280] # tag L31 from tag-slot
    mov [rbp - 1208], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    jmp .Ldd24_rt_parse_int_native_bb10 # branch
.Ldd24_rt_parse_int_native_bb10:
    jmp .Ldd24_rt_parse_int_native_bb11 # branch
.Ldd24_rt_parse_int_native_bb11:
    mov r10, 10 # assign L32
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1288], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    mov r11, 48 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1296], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r10, [rbp - 280] # reload L33 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb13 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb12 # jump -> then
.Ldd24_rt_parse_int_native_bb12:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1312], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r11, [rbp - 296] # reload L35 from spill slot
    mov r10, r11 # assign L36
    mov r11, [rbp - 1312] # tag L35 from tag-slot
    mov [rbp - 1320], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, r13 # hv payload
    mov r11, [rbp - 304] # reload L36 from spill slot
    mov r11, r11 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1328], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r10, r11 # assign L38
    mov r11, [rbp - 1328] # tag L37 from tag-slot
    mov [rbp - 1336], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov r10, r10 # hv payload
    mov r11, 120 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1344], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r11, [rbp - 328] # reload L39 from spill slot
    mov r10, r11 # assign L40
    mov r11, [rbp - 1344] # tag L39 from tag-slot
    mov [rbp - 1352], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov r10, r10 # hv payload
    mov r11, 88 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1360], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L42
    mov r11, [rbp - 1360] # tag L41 from tag-slot
    mov [rbp - 1368], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r11, [rbp - 352] # reload L42 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 336] # reload L40 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1376], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r11, [rbp - 360] # reload L43 from spill slot
    mov r10, r11 # assign L44
    mov r11, [rbp - 1376] # tag L43 from tag-slot
    mov [rbp - 1384], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 368] # reload L44 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1392], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r10, [rbp - 376] # reload L45 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb15 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb14 # jump -> then
.Ldd24_rt_parse_int_native_bb13:
    mov r10, 922337203685477580 # assign L49
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1424], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r10, 7 # assign L50
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1432], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1440], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r10, [rbp - 424] # reload L51 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb17 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb16 # jump -> then
.Ldd24_rt_parse_int_native_bb14:
    mov r10, 16 # assign L32
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1288], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, 2 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1408], r11 # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 392] # reload L47 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1408] # tag L47 from tag-slot
    mov [rbp - 1056], r11 # store tag L3
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1416], r11 # store tag L48
    mov [rbp - 400], r10 # spill L48 to slot
    mov r11, [rbp - 400] # reload L48 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 1416] # tag L48 from tag-slot
    mov [rbp - 1208], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    jmp .Ldd24_rt_parse_int_native_bb15 # branch
.Ldd24_rt_parse_int_native_bb15:
    jmp .Ldd24_rt_parse_int_native_bb13 # branch
.Ldd24_rt_parse_int_native_bb16:
    mov r10, 922337203685477580 # assign L49
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1424], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r10, 8 # assign L50
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1432], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    jmp .Ldd24_rt_parse_int_native_bb17 # branch
.Ldd24_rt_parse_int_native_bb17:
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    mov r11, 16 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1456], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r10, [rbp - 440] # reload L53 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb19 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb18 # jump -> then
.Ldd24_rt_parse_int_native_bb18:
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1472], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov r10, [rbp - 456] # reload L55 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb21 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb20 # jump -> then
.Ldd24_rt_parse_int_native_bb19:
    mov r10, 0 # assign L57
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1488], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    mov r10, 0 # assign L58
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1496], r11 # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov r10, 0 # assign L59
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1504], r11 # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov r10, 1 # assign L60
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1512], r11 # store tag L60
    mov [rbp - 496], r10 # spill L60 to slot
    jmp .Ldd24_rt_parse_int_native_bb23 # branch
.Ldd24_rt_parse_int_native_bb20:
    mov r10, 576460752303423487 # assign L49
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1424], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r10, 15 # assign L50
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1432], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    jmp .Ldd24_rt_parse_int_native_bb22 # branch
.Ldd24_rt_parse_int_native_bb21:
    mov r10, 576460752303423488 # assign L49
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1424], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r10, 0 # assign L50
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1432], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    jmp .Ldd24_rt_parse_int_native_bb22 # branch
.Ldd24_rt_parse_int_native_bb22:
    jmp .Ldd24_rt_parse_int_native_bb19 # branch
.Ldd24_rt_parse_int_native_bb23:
    mov r11, 0 # hv payload
    mov r10, [rbp - 496] # reload L60 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1520], r11 # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r10, [rbp - 504] # reload L61 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb25 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb24 # jump -> then
.Ldd24_rt_parse_int_native_bb24:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1528], r11 # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r11, [rbp - 512] # reload L62 from spill slot
    mov r10, r11 # assign L63
    mov r11, [rbp - 1528] # tag L62 from tag-slot
    mov [rbp - 1536], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    mov r10, 0 # assign L64
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1544], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    mov r10, 0 # assign L65
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1552], r11 # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    mov r11, [rbp - 520] # reload L63 from spill slot
    mov r11, r11 # hv payload
    mov r10, 47 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1560], r11 # store tag L66
    mov [rbp - 544], r10 # spill L66 to slot
    mov r11, [rbp - 544] # reload L66 from spill slot
    mov r10, r11 # assign L67
    mov r11, [rbp - 1560] # tag L66 from tag-slot
    mov [rbp - 1568], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov r11, 58 # hv payload
    mov r10, [rbp - 520] # reload L63 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1576], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    mov r11, [rbp - 560] # reload L68 from spill slot
    mov r10, r11 # assign L69
    mov r11, [rbp - 1576] # tag L68 from tag-slot
    mov [rbp - 1584], r11 # store tag L69
    mov [rbp - 568], r10 # spill L69 to slot
    mov r11, [rbp - 568] # reload L69 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1592], r11 # store tag L70
    mov [rbp - 576], r10 # spill L70 to slot
    mov r11, [rbp - 576] # reload L70 from spill slot
    mov r10, r11 # assign L71
    mov r11, [rbp - 1592] # tag L70 from tag-slot
    mov [rbp - 1600], r11 # store tag L71
    mov [rbp - 584], r10 # spill L71 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 584] # reload L71 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1608], r11 # store tag L72
    mov [rbp - 592], r10 # spill L72 to slot
    mov r10, [rbp - 592] # reload L72 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb27 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb26 # jump -> then
.Ldd24_rt_parse_int_native_bb25:
    mov r10, [rbp - 480] # reload L58 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1944], r11 # store tag L114
    mov [rbp - 928], r10 # spill L114 to slot
    mov r10, [rbp - 928] # reload L114 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb43 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb42 # jump -> then
.Ldd24_rt_parse_int_native_bb26:
    mov r11, 48 # hv payload
    mov r10, [rbp - 520] # reload L63 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1624], r11 # store tag L74
    mov [rbp - 608], r10 # spill L74 to slot
    mov r11, [rbp - 608] # reload L74 from spill slot
    mov r10, r11 # assign L64
    mov r11, [rbp - 1624] # tag L74 from tag-slot
    mov [rbp - 1544], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    mov r10, 1 # assign L65
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1552], r11 # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    jmp .Ldd24_rt_parse_int_native_bb35 # branch
.Ldd24_rt_parse_int_native_bb27:
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    mov r11, 16 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1632], r11 # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    mov r10, [rbp - 616] # reload L75 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb29 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb28 # jump -> then
.Ldd24_rt_parse_int_native_bb28:
    mov r11, [rbp - 520] # reload L63 from spill slot
    mov r11, r11 # hv payload
    mov r10, 96 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1648], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    mov r11, [rbp - 632] # reload L77 from spill slot
    mov r10, r11 # assign L78
    mov r11, [rbp - 1648] # tag L77 from tag-slot
    mov [rbp - 1656], r11 # store tag L78
    mov [rbp - 640], r10 # spill L78 to slot
    mov r11, 103 # hv payload
    mov r10, [rbp - 520] # reload L63 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1664], r11 # store tag L79
    mov [rbp - 648], r10 # spill L79 to slot
    mov r11, [rbp - 648] # reload L79 from spill slot
    mov r10, r11 # assign L80
    mov r11, [rbp - 1664] # tag L79 from tag-slot
    mov [rbp - 1672], r11 # store tag L80
    mov [rbp - 656], r10 # spill L80 to slot
    mov r11, [rbp - 656] # reload L80 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 640] # reload L78 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1680], r11 # store tag L81
    mov [rbp - 664], r10 # spill L81 to slot
    mov r11, [rbp - 664] # reload L81 from spill slot
    mov r10, r11 # assign L82
    mov r11, [rbp - 1680] # tag L81 from tag-slot
    mov [rbp - 1688], r11 # store tag L82
    mov [rbp - 672], r10 # spill L82 to slot
    mov r11, [rbp - 520] # reload L63 from spill slot
    mov r11, r11 # hv payload
    mov r10, 64 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1696], r11 # store tag L83
    mov [rbp - 680], r10 # spill L83 to slot
    mov r11, [rbp - 680] # reload L83 from spill slot
    mov r10, r11 # assign L84
    mov r11, [rbp - 1696] # tag L83 from tag-slot
    mov [rbp - 1704], r11 # store tag L84
    mov [rbp - 688], r10 # spill L84 to slot
    mov r11, 71 # hv payload
    mov r10, [rbp - 520] # reload L63 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1712], r11 # store tag L85
    mov [rbp - 696], r10 # spill L85 to slot
    mov r11, [rbp - 696] # reload L85 from spill slot
    mov r10, r11 # assign L86
    mov r11, [rbp - 1712] # tag L85 from tag-slot
    mov [rbp - 1720], r11 # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    mov r11, [rbp - 704] # reload L86 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 688] # reload L84 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1728], r11 # store tag L87
    mov [rbp - 712], r10 # spill L87 to slot
    mov r11, [rbp - 712] # reload L87 from spill slot
    mov r10, r11 # assign L88
    mov r11, [rbp - 1728] # tag L87 from tag-slot
    mov [rbp - 1736], r11 # store tag L88
    mov [rbp - 720], r10 # spill L88 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 672] # reload L82 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1744], r11 # store tag L89
    mov [rbp - 728], r10 # spill L89 to slot
    mov r10, [rbp - 728] # reload L89 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb31 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb30 # jump -> then
.Ldd24_rt_parse_int_native_bb29:
    jmp .Ldd24_rt_parse_int_native_bb35 # branch
.Ldd24_rt_parse_int_native_bb30:
    mov r11, 87 # hv payload
    mov r10, [rbp - 520] # reload L63 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1760], r11 # store tag L91
    mov [rbp - 744], r10 # spill L91 to slot
    mov r11, [rbp - 744] # reload L91 from spill slot
    mov r10, r11 # assign L64
    mov r11, [rbp - 1760] # tag L91 from tag-slot
    mov [rbp - 1544], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    mov r10, 1 # assign L65
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1552], r11 # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    jmp .Ldd24_rt_parse_int_native_bb34 # branch
.Ldd24_rt_parse_int_native_bb31:
    mov r11, 0 # hv payload
    mov r10, [rbp - 720] # reload L88 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1768], r11 # store tag L92
    mov [rbp - 752], r10 # spill L92 to slot
    mov r10, [rbp - 752] # reload L92 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb33 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb32 # jump -> then
.Ldd24_rt_parse_int_native_bb32:
    mov r11, 55 # hv payload
    mov r10, [rbp - 520] # reload L63 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1784], r11 # store tag L94
    mov [rbp - 768], r10 # spill L94 to slot
    mov r11, [rbp - 768] # reload L94 from spill slot
    mov r10, r11 # assign L64
    mov r11, [rbp - 1784] # tag L94 from tag-slot
    mov [rbp - 1544], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    mov r10, 1 # assign L65
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1552], r11 # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    jmp .Ldd24_rt_parse_int_native_bb33 # branch
.Ldd24_rt_parse_int_native_bb33:
    jmp .Ldd24_rt_parse_int_native_bb34 # branch
.Ldd24_rt_parse_int_native_bb34:
    jmp .Ldd24_rt_parse_int_native_bb29 # branch
.Ldd24_rt_parse_int_native_bb35:
    mov r10, [rbp - 536] # reload L65 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1792], r11 # store tag L95
    mov [rbp - 776], r10 # spill L95 to slot
    mov r10, [rbp - 776] # reload L95 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb37 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb36 # jump -> then
.Ldd24_rt_parse_int_native_bb36:
    mov r10, 0 # assign L60
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1512], r11 # store tag L60
    mov [rbp - 496], r10 # spill L60 to slot
    jmp .Ldd24_rt_parse_int_native_bb41 # branch
.Ldd24_rt_parse_int_native_bb37:
    mov r11, [rbp - 472] # reload L57 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1808], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    mov r11, [rbp - 792] # reload L97 from spill slot
    mov r10, r11 # assign L98
    mov r11, [rbp - 1808] # tag L97 from tag-slot
    mov [rbp - 1816], r11 # store tag L98
    mov [rbp - 800], r10 # spill L98 to slot
    mov r10, [rbp - 472] # reload L57 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 408] # reload L49 from spill slot
    mov r11, r11 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1824], r11 # store tag L99
    mov [rbp - 808], r10 # spill L99 to slot
    mov r11, [rbp - 808] # reload L99 from spill slot
    mov r10, r11 # assign L100
    mov r11, [rbp - 1824] # tag L99 from tag-slot
    mov [rbp - 1832], r11 # store tag L100
    mov [rbp - 816], r10 # spill L100 to slot
    mov r11, [rbp - 528] # reload L64 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 416] # reload L50 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1840], r11 # store tag L101
    mov [rbp - 824], r10 # spill L101 to slot
    mov r11, [rbp - 824] # reload L101 from spill slot
    mov r10, r11 # assign L102
    mov r11, [rbp - 1840] # tag L101 from tag-slot
    mov [rbp - 1848], r11 # store tag L102
    mov [rbp - 832], r10 # spill L102 to slot
    mov r11, [rbp - 832] # reload L102 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 816] # reload L100 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1856], r11 # store tag L103
    mov [rbp - 840], r10 # spill L103 to slot
    mov r11, [rbp - 840] # reload L103 from spill slot
    mov r10, r11 # assign L104
    mov r11, [rbp - 1856] # tag L103 from tag-slot
    mov [rbp - 1864], r11 # store tag L104
    mov [rbp - 848], r10 # spill L104 to slot
    mov r11, [rbp - 848] # reload L104 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 800] # reload L98 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1872], r11 # store tag L105
    mov [rbp - 856], r10 # spill L105 to slot
    mov r11, [rbp - 856] # reload L105 from spill slot
    mov r10, r11 # assign L106
    mov r11, [rbp - 1872] # tag L105 from tag-slot
    mov [rbp - 1880], r11 # store tag L106
    mov [rbp - 864], r10 # spill L106 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 864] # reload L106 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1888], r11 # store tag L107
    mov [rbp - 872], r10 # spill L107 to slot
    mov r10, [rbp - 872] # reload L107 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb39 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb38 # jump -> then
.Ldd24_rt_parse_int_native_bb38:
    mov r10, 1 # assign L59
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1504], r11 # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    jmp .Ldd24_rt_parse_int_native_bb40 # branch
.Ldd24_rt_parse_int_native_bb39:
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 472] # reload L57 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1904], r11 # store tag L109
    mov [rbp - 888], r10 # spill L109 to slot
    mov r11, [rbp - 888] # reload L109 from spill slot
    mov r10, r11 # assign L110
    mov r11, [rbp - 1904] # tag L109 from tag-slot
    mov [rbp - 1912], r11 # store tag L110
    mov [rbp - 896], r10 # spill L110 to slot
    mov r11, [rbp - 528] # reload L64 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 896] # reload L110 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1920], r11 # store tag L111
    mov [rbp - 904], r10 # spill L111 to slot
    mov r11, [rbp - 904] # reload L111 from spill slot
    mov r10, r11 # assign L57
    mov r11, [rbp - 1920] # tag L111 from tag-slot
    mov [rbp - 1488], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    jmp .Ldd24_rt_parse_int_native_bb40 # branch
.Ldd24_rt_parse_int_native_bb40:
    mov r11, 1 # hv payload
    mov r10, [rbp - 480] # reload L58 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1928], r11 # store tag L112
    mov [rbp - 912], r10 # spill L112 to slot
    mov r11, [rbp - 912] # reload L112 from spill slot
    mov r10, r11 # assign L58
    mov r11, [rbp - 1928] # tag L112 from tag-slot
    mov [rbp - 1496], r11 # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1936], r11 # store tag L113
    mov [rbp - 920], r10 # spill L113 to slot
    mov r10, [rbp - 920] # reload L113 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1936] # tag L113 from tag-slot
    mov [rbp - 1056], r11 # store tag L3
    jmp .Ldd24_rt_parse_int_native_bb41 # branch
.Ldd24_rt_parse_int_native_bb41:
    jmp .Ldd24_rt_parse_int_native_bb23 # branch
.Ldd24_rt_parse_int_native_bb42:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 2000 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Ldd24_rt_parse_int_native_bb43:
    mov r11, 0 # hv payload
    mov r10, [rbp - 488] # reload L59 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1960], r11 # store tag L116
    mov [rbp - 944], r10 # spill L116 to slot
    mov r10, [rbp - 944] # reload L116 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb45 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb44 # jump -> then
.Ldd24_rt_parse_int_native_bb44:
    mov r11, 0 # hv payload
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1976], r11 # store tag L118
    mov [rbp - 960], r10 # spill L118 to slot
    mov r10, [rbp - 960] # reload L118 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb47 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb46 # jump -> then
.Ldd24_rt_parse_int_native_bb45:
    mov r11, 0 # hv payload
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2024], r11 # store tag L124
    mov [rbp - 1008], r10 # spill L124 to slot
    mov r10, [rbp - 1008] # reload L124 from spill slot
    test r10, r10 # br_cond test
    jz .Ldd24_rt_parse_int_native_bb49 # jump-if-zero -> else
    jmp .Ldd24_rt_parse_int_native_bb48 # jump -> then
.Ldd24_rt_parse_int_native_bb46:
    mov r11, 9223372036854775807 # hv payload
    mov r10, 0 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1992], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    mov r11, [rbp - 976] # reload L120 from spill slot
    mov r10, r11 # assign L121
    mov r11, [rbp - 1992] # tag L120 from tag-slot
    mov [rbp - 2000], r11 # store tag L121
    mov [rbp - 984], r10 # spill L121 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 984] # reload L121 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2008], r11 # store tag L122
    mov [rbp - 992], r10 # spill L122 to slot
    mov r11, [rbp - 992] # reload L122 from spill slot
    mov r10, r11 # assign L123
    mov r11, [rbp - 2008] # tag L122 from tag-slot
    mov [rbp - 2016], r11 # store tag L123
    mov [rbp - 1000], r10 # spill L123 to slot
    mov rdx, [rbp - 1000] # reload L123 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2016] # tag L123 from tag-slot
    add rsp, 2000 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Ldd24_rt_parse_int_native_bb47:
    mov rdx, 9223372036854775807 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 2000 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Ldd24_rt_parse_int_native_bb48:
    mov r11, [rbp - 472] # reload L57 from spill slot
    mov r11, r11 # hv payload
    mov r10, 0 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2040], r11 # store tag L126
    mov [rbp - 1024], r10 # spill L126 to slot
    mov rdx, [rbp - 1024] # reload L126 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2040] # tag L126 from tag-slot
    add rsp, 2000 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Ldd24_rt_parse_int_native_bb49:
    mov rdx, [rbp - 472] # reload L57 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1488] # tag L57 from tag-slot
    add rsp, 2000 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

.section .note.GNU-stack,"",@progbits
