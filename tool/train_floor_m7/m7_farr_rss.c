/* HEXA-TRAIN-FLOOR M7 — HEXA_FARR_TRIM RSS-churn A/B (faithful to the
 * runtime_core_emit.hexa __attribute__((constructor)) malloc-tuning).
 * Reproduces the trainer per-step alloc pattern: large packed-double farr
 * chunks (V*8B ~1.2MB) interleaved with small weight-extract chunks
 * (32-128KB), free'd each step. Without the mallopt the small chunks pin the
 * arena top so free'd large chunks accumulate -> monotonic RSS climb.
 * HEXA_FARR_TRIM=1 lowers M_MMAP/M_TRIM_THRESHOLD to 256KiB at startup so
 * large chunks munmap on free. Measures per-step RSS delta both ways. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include <unistd.h>

static long rss_kb(void){
    FILE* f=fopen("/proc/self/statm","r");
    if(!f) return 0;
    long total=0,res=0;
    if(fscanf(f,"%ld %ld",&total,&res)!=2){fclose(f);return 0;}
    fclose(f);
    return res*(sysconf(_SC_PAGESIZE)/1024);
}

int main(int argc,char**argv){
    int steps = (argc>1)?atoi(argv[1]):200;
    const char* on = getenv("HEXA_FARR_TRIM");
    int trim = (on && on[0]=='1' && on[1]=='\0');
    if(trim){
        long mmap_kb=256, trim_kb=256;
        const char* mk=getenv("HEXA_FARR_MMAP_KB"); if(mk&&*mk){long v=atol(mk);if(v>0)mmap_kb=v;}
        const char* tk=getenv("HEXA_FARR_TRIM_KB"); if(tk&&*tk){long v=atol(tk);if(v>0)trim_kb=v;}
        mallopt(M_MMAP_THRESHOLD,(int)(mmap_kb*1024));
        mallopt(M_TRIM_THRESHOLD,(int)(trim_kb*1024));
    }
    printf("# HEXA_FARR_TRIM=%s  steps=%d\n", trim?"1(ON)":"0/unset(OFF)", steps);
    long rss0=rss_kb();
    long rss_first=0;
    /* warmup a couple steps so the rss baseline is post-allocator-init */
    for(int s=0;s<steps;s++){
        /* per step: 1 large (1.2MB) + several small (interleaved, pinning) */
        size_t big = 1200*1024;        /* ~1.2 MB packed-double farr */
        char* L = malloc(big); memset(L,s&0xff,big);
        /* small chunks held across the large free (the pinning pattern) */
        char* S[8]; size_t ss[8]={32,48,64,96,128,64,48,32};
        for(int k=0;k<8;k++){ S[k]=malloc(ss[k]*1024); memset(S[k],k,ss[k]*1024); }
        /* free the large chunk (returns to OS only if mmap-backed) */
        free(L);
        /* free the smalls */
        for(int k=0;k<8;k++) free(S[k]);
        if(s==4) rss_first=rss_kb();
        if(s%40==0 || s==steps-1)
            printf("step %3d  RSS %ld KB  (delta vs s0 = %+ld KB)\n", s, rss_kb(), rss_kb()-rss0);
    }
    long rssN=rss_kb();
    printf("# rss s0=%ld KB  s4=%ld KB  sN=%ld KB\n", rss0, rss_first, rssN);
    long span = (steps>4)?(steps-4):1;
    printf("# net climb (s4->sN) = %+ld KB over %ld steps = %+.2f KB/step\n",
           rssN-rss_first, span, (double)(rssN-rss_first)/span);
    return 0;
}
