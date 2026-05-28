/* test/native_build/poc_classb_branch26_callee.c
 *
 * B9.6-B1 class-B link+run oracle — the CALLEE, defined in a SEPARATE .o so
 * the hexa-emitted _the_composite's ARM64_RELOC_BRANCH26 (`bl _the_callee`)
 * binds across objects at link time. Returns 0x1234567800000063: the low 32
 * bits = 99 (0x63), so the composite's `(int)` truncation yields 99 — proving
 * the cross-object call returned and the result propagated.
 *
 * Repro:  hexa-run poc_classb_branch26_emit.hexa            # -> /tmp/poc_classb.o
 *         cc -c poc_classb_branch26_callee.c -o callee.o
 *         cc /tmp/poc_classb.o callee.o poc_classb_branch26_caller.c -o exe
 *         ./exe ; echo $?                                    # -> "the_composite() = 99", rc 0
 * Links with LC_SYMTAB only (NO LC_DYSYMTAB) — resolves the macho.hexa #1475
 * "link-test pending" caveat for the BRANCH26 cross-object-call case.
 */
long long the_callee(const char *s) { (void)s; return 0x1234567800000063LL; } /* low32 = 99 */
