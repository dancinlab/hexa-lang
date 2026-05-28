/* test/native_build/poc_classb_branch26_caller.c
 *
 * B9.6-B1 class-B link+run oracle — the CALLER (main). Invokes the
 * hexa-emitted _the_composite (frame + `bl _the_callee` + epilogue, returns
 * (int)) and checks the low-32 result == 99. Exit 0 == PASS. Crucially this
 * MUST exit (not spin): a frameless composite that omits the stp/ldp frame
 * loops forever (ret reuses a clobbered x30) — the frame is the load-bearing
 * class-B difference this oracle pins.
 */
#include <stdio.h>
extern int the_composite(const char *s);  /* hexa-emit: frame + bl the_callee + epilogue, return (int) */
int main(void) {
    int r = the_composite("ignored");
    printf("the_composite() = %d\n", r);
    return (r == 99) ? 0 : 1;
}
