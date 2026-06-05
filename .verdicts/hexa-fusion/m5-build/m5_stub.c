#include "runtime.h"
/* M2 full-step AdamW (forge_dispatch_adamw_fused) not in p1kit runtime -> stub
   returns -1 so the .hexa gate falls back to per-param _adam (eager AdamW). */
HexaVal forge_dispatch_adamw_fused(HexaVal a,HexaVal b,HexaVal c,HexaVal d,HexaVal e,HexaVal f,HexaVal g,HexaVal h,HexaVal i,HexaVal j,HexaVal k,HexaVal l){(void)a;(void)b;(void)c;(void)d;(void)e;(void)f;(void)g;(void)h;(void)i;(void)j;(void)k;(void)l;return hexa_int(-1);}
