// ════════════════════════════════════════════════════════════════════════════
//  ring_perf_m6c.c — HEXA-DDP DDP-M6c: RE-PIPELINE the WAN ring to OVERLAP its
//  two phases (full-duplex send||recv + chunk pipelining), beating the M6b
//  RTT-bound throughput ceiling.
//
//  M6b FINDING (the wall this fixes): the M6 cross-node ring all-reduce is
//  byte-exact over a real intercontinental WAN, but its throughput is RTT-bound
//  and tiny (~30-40 KB/s, a 1MB all-reduce = ~31s, RTT ~300ms). M6b proved
//  (32MB TCP-buffer sweep = clean negative) the limiter is NOT the TCP window
//  but the ring's per-phase BLOCKING send-then-recv that serializes ONE FULL
//  RTT per phase: a rank `send`s its whole chunk and only THEN `recv`s the
//  incoming chunk, so the wire goes idle for a full one-way delay each phase.
//
//  M6c re-pipelines the EXACT M6 ring schedule (2(N-1) steps, chunk_start
//  partition, parity ordering) — the MATH is byte-for-byte unchanged — but
//  changes ONLY the transport's blocking discipline:
//
//    (A) FULL-DUPLEX per step: a dedicated SENDER THREAD pushes this step's
//        outbound chunk while the MAIN THREAD simultaneously pulls the inbound
//        chunk. Send and recv proceed concurrently on the two TCP half-duplex
//        directions instead of being serialized. This collapses the per-phase
//        cost from (send-latency + recv-latency) toward max(one-way).
//
//    (B) CHUNK PIPELINING: each step's chunk is split into P sub-chunks; the
//        sender streams sub-chunk i while the receiver drains sub-chunk i-1,
//        keeping multiple sub-chunks in flight so TCP fills the pipe across the
//        bandwidth-delay product instead of stalling.
//
//  The reduce (x[i] += stage[i]) is byte-identical and runs AFTER the inbound
//  chunk is fully received for that step (same accumulation ORDER as M6/M6b →
//  FP64 byte-eq preserved; no reordering of float adds).
//
//  MODES (isolate overlap vs the M6b serial baseline on the SAME path):
//    --mode serial   : exact M6b blocking send-then-recv (baseline re-measure).
//    --mode duplex   : (A) full-duplex send||recv, P=1.
//    --mode pipeline : (A)+(B) full-duplex + P sub-chunks (--pchunks P).
//
//  GATES (g5):
//    (1) CORRECTNESS: --check runs a known-sum all-reduce (S%2!=0 boundary +
//        large S) and verifies result == serial elementwise sum byte-eq
//        max|Δ|=0, FP64, for EVERY mode. Overlap must NOT corrupt the reduction.
//    (2) THROUGHPUT: same BW-vs-msgsize ladder as M6b; report median wall,
//        algo_GB/s, wire_GB/s per S per mode → speedup over the serial baseline.
//
//  HONEST (g5): WAN stays RTT-dominated. Full-duplex removes the per-phase
//  send-then-recv serialization (≈2x from duplexing the two one-way legs);
//  pipelining keeps the pipe full so large messages approach link bandwidth.
//  Neither can beat the fundamental ~RTT latency floor — a 2-node all-reduce
//  still pays >= ~1 RTT of round-trip dependency. We report the REAL factor and
//  the residual floor. NOT datacenter/RDMA.
//
//  Build:  cc -O2 -pthread -o ring_perf_m6c ring_perf_m6c.c -lm
// ════════════════════════════════════════════════════════════════════════════
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>

static void die(const char* m){ perror(m); exit(2); }

enum { MODE_SERIAL=0, MODE_DUPLEX=1, MODE_PIPELINE=2 };
static int   g_sockbuf = 0;
static int   g_mode    = MODE_PIPELINE;
static int   g_pchunks = 8;

static void apply_sockbuf(int cs){
    if (g_sockbuf > 0){
        setsockopt(cs, SOL_SOCKET, SO_SNDBUF, &g_sockbuf, sizeof g_sockbuf);
        setsockopt(cs, SOL_SOCKET, SO_RCVBUF, &g_sockbuf, sizeof g_sockbuf);
    }
}
static double now_s(void){
    struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + (double)t.tv_nsec * 1e-9;
}
static long chunk_start(long S, int N, int c){
    long base = S / N, rem = S % N;
    if (c <= rem) return (long)c * (base + 1);
    return rem * (base + 1) + (long)(c - rem) * base;
}
static int sendall(int fd, const void* buf, size_t n){
    const char* p = (const char*)buf;
    while (n){ ssize_t k = send(fd, p, n, 0);
        if (k < 0){ if (errno==EINTR) continue; return -1; }
        if (k == 0) return -1; p += k; n -= (size_t)k; }
    return 0;
}
static int recvall(int fd, void* buf, size_t n){
    char* p = (char*)buf;
    while (n){ ssize_t k = recv(fd, p, n, 0);
        if (k < 0){ if (errno==EINTR) continue; return -1; }
        if (k == 0) return -1; p += k; n -= (size_t)k; }
    return 0;
}
static void parse_hp(const char* hp, char* host, int* port){
    const char* colon = strrchr(hp, ':');
    if (!colon){ fprintf(stderr,"bad host:port %s\n",hp); exit(2);}
    size_t hl = (size_t)(colon-hp); memcpy(host,hp,hl); host[hl]=0;
    *port = atoi(colon+1);
}
static int listen_one(const char* hostport){
    char host[256]; int port; parse_hp(hostport, host, &port);
    int ls = socket(AF_INET, SOCK_STREAM, 0); if (ls<0) die("socket");
    int one=1; setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
    apply_sockbuf(ls);
    struct sockaddr_in a; memset(&a,0,sizeof a);
    a.sin_family=AF_INET; a.sin_port=htons((uint16_t)port);
    a.sin_addr.s_addr = (!strcmp(host,"0.0.0.0")||!host[0]) ? INADDR_ANY
                                                            : inet_addr(host);
    if (bind(ls,(struct sockaddr*)&a,sizeof a)<0) die("bind");
    if (listen(ls,1)<0) die("listen");
    fprintf(stderr,"[rank] listening on %s\n", hostport);
    int cs = accept(ls,NULL,NULL); if (cs<0) die("accept");
    close(ls);
    int one2=1; setsockopt(cs, IPPROTO_TCP, TCP_NODELAY, &one2, sizeof one2);
    return cs;
}
static int connect_succ(const char* hostport){
    char host[256]; int port; parse_hp(hostport, host, &port);
    struct sockaddr_in a; memset(&a,0,sizeof a);
    a.sin_family=AF_INET; a.sin_port=htons((uint16_t)port);
    struct in_addr ina;
    if (inet_aton(host,&ina)) a.sin_addr=ina;
    else { struct hostent* he=gethostbyname(host);
           if(!he){fprintf(stderr,"resolve %s failed\n",host);exit(2);}
           memcpy(&a.sin_addr,he->h_addr,he->h_length); }
    for (int tries=0; tries<600; tries++){
        int cs = socket(AF_INET,SOCK_STREAM,0); if(cs<0) die("socket");
        apply_sockbuf(cs);
        if (connect(cs,(struct sockaddr*)&a,sizeof a)==0){
            int one=1; setsockopt(cs,IPPROTO_TCP,TCP_NODELAY,&one,sizeof one);
            fprintf(stderr,"[rank] connected succ %s\n",hostport);
            return cs;
        }
        close(cs); usleep(200000);
    }
    fprintf(stderr,"connect %s timed out\n",hostport); exit(2);
}

typedef struct {
    int    fd;
    const double* src;
    long   off;
    long   n;
    int    pchunks;
    int    rc;
} send_arg_t;

static void* send_thread(void* v){
    send_arg_t* a = (send_arg_t*)v;
    a->rc = 0;
    if (a->n <= 0) return NULL;
    int P = a->pchunks < 1 ? 1 : a->pchunks;
    if (P > a->n) P = (int)a->n;
    long per = a->n / P, rem = a->n % P, cur = a->off;
    for (int i=0;i<P;i++){
        long cnt = per + (i < rem ? 1 : 0);
        if (cnt > 0){
            if (sendall(a->fd, a->src + cur, (size_t)cnt*sizeof(double))){
                a->rc = -1; return NULL;
            }
            cur += cnt;
        }
    }
    return NULL;
}
static int recv_region(int fd, double* dst, long off, long n, int pchunks){
    if (n <= 0) return 0;
    int P = pchunks < 1 ? 1 : pchunks;
    if (P > n) P = (int)n;
    long per = n / P, rem = n % P, cur = off;
    for (int i=0;i<P;i++){
        long cnt = per + (i < rem ? 1 : 0);
        if (cnt > 0){
            if (recvall(fd, dst + cur, (size_t)cnt*sizeof(double))) return -1;
            cur += cnt;
        }
    }
    return 0;
}

static double one_allreduce(int rank, int N, long S, double* x, double* stage,
                            int sock_succ, int sock_pred){
    double t0 = now_s();
    int P = (g_mode == MODE_PIPELINE) ? g_pchunks : 1;

    #define DO_STEP(SC, RC, ADD) do {                                          \
        long s_st=chunk_start(S,N,(SC)), s_sp=chunk_start(S,N,(SC)+1);          \
        long r_st=chunk_start(S,N,(RC)), r_sp=chunk_start(S,N,(RC)+1);          \
        long s_n=s_sp-s_st, r_n=r_sp-r_st;                                     \
        if (g_mode == MODE_SERIAL){                                            \
            if (rank % 2 == 0){                                                \
                if (s_n && sendall(sock_succ, x+s_st,                           \
                                   (size_t)s_n*sizeof(double))) die("send");    \
                if (r_n && recvall(sock_pred, stage+r_st,                       \
                                   (size_t)r_n*sizeof(double))) die("recv");    \
            } else {                                                          \
                if (r_n && recvall(sock_pred, stage+r_st,                       \
                                   (size_t)r_n*sizeof(double))) die("recv");    \
                if (s_n && sendall(sock_succ, x+s_st,                           \
                                   (size_t)s_n*sizeof(double))) die("send");    \
            }                                                                 \
        } else {                                                              \
            send_arg_t sa = { sock_succ, x, s_st, s_n, P, 0 };                  \
            pthread_t th; int spawned = 0;                                     \
            if (s_n){ if (pthread_create(&th,NULL,send_thread,&sa))            \
                          die("pthread_create"); spawned = 1; }                \
            if (r_n && recv_region(sock_pred, stage, r_st, r_n, P))            \
                die("recv");                                                   \
            if (spawned){ pthread_join(th,NULL);                              \
                          if (sa.rc) die("send"); }                            \
        }                                                                     \
        if (r_n){                                                             \
            if (ADD) for(long i=r_st;i<r_sp;i++) x[i]+=stage[i];                \
            else     for(long i=r_st;i<r_sp;i++) x[i] =stage[i];                \
        }                                                                     \
    } while(0)

    for (int step=0; step<N-1; step++){
        int send_chunk = ((rank - step) % N + N) % N;
        int recv_chunk = ((((rank-1)%N+N)%N - step) % N + N) % N;
        DO_STEP(send_chunk, recv_chunk, 1);
    }
    for (int step=0; step<N-1; step++){
        int send_chunk = ((rank - step + 1) % N + N) % N;
        int recv_chunk = ((((rank-1)%N+N)%N - step + 1) % N + N) % N;
        DO_STEP(send_chunk, recv_chunk, 0);
    }
    #undef DO_STEP
    return now_s() - t0;
}

static int cmp_d(const void* a, const void* b){
    double x=*(const double*)a, y=*(const double*)b;
    return (x<y)?-1:(x>y)?1:0;
}
static double measure_rtt(int rank, int N, int sock_succ, int sock_pred,
                          int pings){
    if (N != 2) return -1.0;
    unsigned char tok = 0xA5;
    double* samp = (double*)malloc((size_t)pings*sizeof(double));
    int nsamp = 0;
    for (int p=0; p<pings; p++){
        if (rank == 0){
            double t0 = now_s();
            if (sendall(sock_succ, &tok, 1)) die("ping send");
            if (recvall(sock_pred, &tok, 1)) die("ping recv");
            samp[nsamp++] = (now_s() - t0) * 1e3;
        } else {
            if (recvall(sock_pred, &tok, 1)) die("ping echo recv");
            if (sendall(sock_succ, &tok, 1)) die("ping echo send");
        }
    }
    double med = -1.0;
    if (rank == 0 && nsamp){
        qsort(samp, (size_t)nsamp, sizeof(double), cmp_d);
        med = samp[nsamp/2];
    }
    free(samp);
    return med;
}

static int correctness_check(int rank, int N, long S, double* x, double* x0,
                             double* stage, double* ref,
                             int sock_succ, int sock_pred){
    for (long i=0;i<S;i++)
        x0[i] = (double)(((long)rank*1000003L + i*7L + 1) % 9973) - 4096.0;
    for (long i=0;i<S;i++){
        double s = 0.0;
        for (int r=0;r<N;r++)
            s += (double)(((long)r*1000003L + i*7L + 1) % 9973) - 4096.0;
        ref[i] = s;
    }
    memcpy(x, x0, (size_t)S*sizeof(double));
    (void)one_allreduce(rank, N, S, x, stage, sock_succ, sock_pred);
    long mism = 0; double maxabs = 0.0;
    for (long i=0;i<S;i++){
        double d = fabs(x[i] - ref[i]);
        if (d != 0.0){ mism++; if (d>maxabs) maxabs=d; }
    }
    if (rank == 0)
        printf("CHECK mode=%d S=%ld pchunks=%d : mismatches=%ld max|delta|=%.17g %s\n",
               g_mode, S, (g_mode==MODE_PIPELINE?g_pchunks:1), mism, maxabs,
               (mism==0?"BYTE-EQ-PASS":"FAIL"));
    return mism==0 ? 0 : 1;
}

int main(int argc, char** argv){
    int rank=-1, N=-1, reps=11, pings=50, do_check=0;
    long single=0;
    long maxs_cap=0;  // if >0, cap the sweep ladder to S <= maxs_cap (WAN-bounded run)
    const char *listen_hp=NULL, *succ_hp=NULL, *modestr="pipeline";
    for (int i=1;i<argc;i++){
        if(!strcmp(argv[i],"--rank")) rank=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--np")) N=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--reps")) reps=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--ping")) pings=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--single")) single=atol(argv[++i]);
        else if(!strcmp(argv[i],"--maxs")) maxs_cap=atol(argv[++i]);
        else if(!strcmp(argv[i],"--sockbuf")) g_sockbuf=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--pchunks")) g_pchunks=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--mode")) modestr=argv[++i];
        else if(!strcmp(argv[i],"--check")) do_check=1;
        else if(!strcmp(argv[i],"--listen")) listen_hp=argv[++i];
        else if(!strcmp(argv[i],"--succ")) succ_hp=argv[++i];
        else { fprintf(stderr,"unknown arg %s\n",argv[i]); return 2; }
    }
    if(rank<0||N<2||!listen_hp||!succ_hp){
        fprintf(stderr,"usage: --rank R --np N --listen H:P --succ H:P "
                       "[--mode serial|duplex|pipeline] [--pchunks P] "
                       "[--reps n] [--ping n] [--check]\n");
        return 2;
    }
    if      (!strcmp(modestr,"serial"))   g_mode=MODE_SERIAL;
    else if (!strcmp(modestr,"duplex"))   g_mode=MODE_DUPLEX;
    else if (!strcmp(modestr,"pipeline")) g_mode=MODE_PIPELINE;
    else { fprintf(stderr,"bad --mode %s\n",modestr); return 2; }

    fprintf(stderr,"[rank %d/%d] listen=%s succ=%s mode=%s pchunks=%d reps=%d "
            "pings=%d\n", rank,N,listen_hp,succ_hp,modestr,g_pchunks,reps,pings);

    int sock_succ=-1, sock_pred=-1;
    if (rank % 2 == 0){ sock_succ=connect_succ(succ_hp); sock_pred=listen_one(listen_hp); }
    else              { sock_pred=listen_one(listen_hp); sock_succ=connect_succ(succ_hp); }

    double rtt_ms = measure_rtt(rank, N, sock_succ, sock_pred, pings);
    if (rank == 0)
        printf("RTT_PING median_round_trip_ms = %.4f  (over %d pings, 1-byte)\n",
               rtt_ms, pings);

    long ladder[] = {
        128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072,
        262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432,
    };
    int nL = (int)(sizeof(ladder)/sizeof(ladder[0]));
    long single_arr[1];
    if (single > 0){ single_arr[0]=single; nL=1; }
    long* L = (single > 0) ? single_arr : ladder;
    if (single<=0 && maxs_cap>0){ int k=0; while(k<nL && ladder[k]<=maxs_cap) k++; if(k>0) nL=k; }
    #define LAD(k) (L[(k)])
    long maxS = LAD(nL-1);
    if (maxS < 1048575L) maxS = 1048575L; /* room for check sizes */

    double* x     = (double*)malloc((size_t)maxS*sizeof(double));
    double* x0    = (double*)malloc((size_t)maxS*sizeof(double));
    double* stage = (double*)malloc((size_t)maxS*sizeof(double));
    double* ref   = (double*)malloc((size_t)maxS*sizeof(double));
    if(!x||!x0||!stage||!ref) die("malloc");

    if (do_check){
        int fail = 0;
        long checkS[] = { 7, 13, 1023, 1048575 };
        int saved_mode = g_mode;
        for (int m=MODE_SERIAL; m<=MODE_PIPELINE; m++){
            g_mode = m;
            for (int ci=0; ci<(int)(sizeof(checkS)/sizeof(checkS[0])); ci++){
                long S = checkS[ci];
                if (S > maxS) continue;
                fail |= correctness_check(rank, N, S, x, x0, stage, ref,
                                          sock_succ, sock_pred);
            }
        }
        g_mode = saved_mode;
        if (rank == 0) printf("CHECK_OVERALL = %s\n", fail?"FAIL":"ALL-BYTE-EQ-PASS");
    }

    for (long i=0;i<maxS;i++)
        x0[i] = (double)(((long)rank*1000003L + i*7L + 1) % 9973) - 4096.0;

    if (rank == 0){
        printf("# DDP-M6c WAN all-reduce throughput sweep "
               "(N=%d, mode=%s, pchunks=%d, reps=%d, sockbuf=%d, median)\n",
               N, modestr, (g_mode==MODE_PIPELINE?g_pchunks:1), reps, g_sockbuf);
        printf("#  S_elems   payload_B   wire_B    median_s      algo_GB/s   wire_GB/s\n");
    }
    double* samp = (double*)malloc((size_t)reps*sizeof(double));
    for (int li=0; li<nL; li++){
        long S = LAD(li);
        long wire_elems = 0;
        for (int step=0; step<N-1; step++){
            int sc = ((rank - step) % N + N) % N;
            wire_elems += chunk_start(S,N,sc+1)-chunk_start(S,N,sc);
        }
        for (int step=0; step<N-1; step++){
            int sc = ((rank - step + 1) % N + N) % N;
            wire_elems += chunk_start(S,N,sc+1)-chunk_start(S,N,sc);
        }
        size_t payload_B = (size_t)S * sizeof(double);
        size_t wire_B    = (size_t)wire_elems * sizeof(double);

        memcpy(x, x0, (size_t)S*sizeof(double));
        (void)one_allreduce(rank, N, S, x, stage, sock_succ, sock_pred);
        for (int r=0; r<reps; r++){
            memcpy(x, x0, (size_t)S*sizeof(double));
            samp[r] = one_allreduce(rank, N, S, x, stage, sock_succ, sock_pred);
        }
        qsort(samp, (size_t)reps, sizeof(double), cmp_d);
        double med = samp[reps/2];
        double algo_gbs = (med>0) ? ((double)payload_B / med) / 1e9 : 0.0;
        double wire_gbs = (med>0) ? ((double)wire_B    / med) / 1e9 : 0.0;
        if (rank == 0){
            printf("%10ld  %9zu  %9zu  %.8f  %10.5f  %10.5f\n",
                   S, payload_B, wire_B, med, algo_gbs, wire_gbs);
            fflush(stdout);
        }
    }

    free(x); free(x0); free(stage); free(ref); free(samp);
    close(sock_succ); close(sock_pred);
    return 0;
}
