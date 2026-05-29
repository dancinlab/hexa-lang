/* M7 farr-trim RSS A/B — variant 2: faithful pinning. The trainer's small
 * weight-extract chunks are allocated AFTER the large farr each step and
 * outlive it (retained in a growing pool), so each step's large farr free
 * lands behind a pinned top chunk and cannot return to the OS under default
 * glibc -> arena grows ~1.2MB/step. HEXA_FARR_TRIM=1 makes the large chunk
 * mmap-backed so its free munmaps regardless of arena top. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include <unistd.h>
static long rss_kb(void){
    FILE* f=fopen("/proc/self/statm","r"); if(!f) return 0;
    long t=0,r=0; if(fscanf(f,"%ld %ld",&t,&r)!=2){fclose(f);return 0;} fclose(f);
    return r*(sysconf(_SC_PAGESIZE)/1024);
}
int main(int argc,char**argv){
    int steps=(argc>1)?atoi(argv[1]):200;
    const char* on=getenv("HEXA_FARR_TRIM");
    int trim=(on&&on[0]=='1'&&on[1]=='\0');
    if(trim){ mallopt(M_MMAP_THRESHOLD,256*1024); mallopt(M_TRIM_THRESHOLD,256*1024); }
    printf("# HEXA_FARR_TRIM=%s steps=%d (pinning variant)\n", trim?"1(ON)":"OFF", steps);
    /* a small retained pool that keeps growing the arena top */
    char** pin = calloc(steps, sizeof(char*));
    long rss0=rss_kb(), rss4=0;
    for(int s=0;s<steps;s++){
        size_t big=1200*1024;
        char* L=malloc(big); memset(L,s&0xff,big);   /* large farr */
        /* a small chunk allocated AFTER the large, retained (pins top) */
        pin[s]=malloc(64*1024); memset(pin[s],s,64*1024);
        free(L);                                     /* large freed; behind pinned top */
        if(s==4) rss4=rss_kb();
        if(s%40==0||s==steps-1) printf("step %3d RSS %ld KB (delta s0 %+ld)\n",s,rss_kb(),rss_kb()-rss0);
    }
    long rssN=rss_kb();
    printf("# s0=%ld s4=%ld sN=%ld KB\n",rss0,rss4,rssN);
    long span=(steps>4)?steps-4:1;
    printf("# net climb s4->sN = %+ld KB over %ld steps = %+.2f KB/step\n",rssN-rss4,span,(double)(rssN-rss4)/span);
    for(int s=0;s<steps;s++) if(pin[s]) free(pin[s]);
    free(pin); return 0;
}
