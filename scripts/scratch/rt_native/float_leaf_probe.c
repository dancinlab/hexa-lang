/* float_leaf_probe.c — gate for float_leaf_probe.hexa::rt_float_probe.
 * Confirms __hx_to_double / fdiv / fmul / fadd lower+run bit-exact in a seed.
 * Build: clang -O2 -std=gnu11 float_leaf_probe.c probe.o -o p && ./p
 */
#include <stdio.h>
#include <stdint.h>
typedef enum { TAG_INT=0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID } HexaTag;
typedef struct HexaVal_ { HexaTag tag; union { int64_t i; double f; void* p; }; } HexaVal;
#define HX_FLOAT(v) ((v).f)
static HexaVal hxi(int64_t n){ HexaVal v; v.tag=TAG_INT; v.i=n; return v; }
extern HexaVal rt_float_probe(HexaVal a, HexaVal b);
int main(void){
    int fails=0, checks=0;
    long pairs[][2] = {{1,3},{7,2},{10,4},{355,113},{0,5},{-3,7},{123456,1000}};
    for(int k=0;k<7;k++){
        long a=pairs[k][0], b=pairs[k][1];
        double nat = HX_FLOAT(rt_float_probe(hxi(a), hxi(b)));
        double ref = (double)a/(double)b*10.0+(double)a;
        checks++;
        int eq = (nat==ref) || (nat!=nat && ref!=ref);
        if(!eq){ fails++; fprintf(stderr,"FAIL a=%ld b=%ld nat=%.17g ref=%.17g\n",a,b,nat,ref); }
    }
    printf("[float_probe] %s — %d checks, %d fails\n", fails?"FAIL":"PASS", checks, fails);
    return fails?1:25;
}
