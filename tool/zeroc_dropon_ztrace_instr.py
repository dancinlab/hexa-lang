import sys
p = sys.argv[1]
t = open(p).read()
inj = (
    '\n#include <stdio.h>\n'
    'static int __zt_on(void){static int v=-1; if(v<0){const char*e=getenv("ZTRACE"); v=(e&&e[0]==0x31)?1:0;} return v;}\n'
    'static long __zt_sets=0,__zt_gets=0,__zt_miss=0;\n'
)
t = t.replace('\n', inj, 1)

nk = '        t->vals[idx] = stored;\n        t->order_keys[t->len] = t->slots[idx].key;'
tr = '        if(__zt_on()){__zt_sets++; fprintf(stderr,"ZSET key=%s h=%u idx=%u cap=%u tbl=%p\\n",k,(unsigned)h,(unsigned)idx,(unsigned)t->ht_cap,(void*)t);}\n'
assert nk in t, "pack needle missing"
t = t.replace(nk, tr + nk, 1)

hf = 'int hmap_find(HexaMapTable* t, const char* key, uint32_t h) {\n'
hft = hf + '    if(__zt_on()){__zt_gets++; fprintf(stderr,"ZGET key=%s h=%u cap=%u tbl=%p\\n",key,(unsigned)h,(unsigned)(t?t->ht_cap:0),(void*)t);}\n'
assert hf in t, "hmap_find sig missing"
t = t.replace(hf, hft, 1)

mr = '    }\n    return -1;\n}\n'
mrt = '    }\n    if(__zt_on()){__zt_miss++; fprintf(stderr,"ZMISS key=%s h=%u tbl=%p sets=%ld gets=%ld miss=%ld\\n",key,(unsigned)h,(void*)t,__zt_sets,__zt_gets,__zt_miss);}\n    return -1;\n}\n'
assert mr in t, "return -1 needle missing"
t = t.replace(mr, mrt, 1)

open(p, 'w').write(t)
print("instrumented OK")
