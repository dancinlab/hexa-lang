// ════════════════════════════════════════════════════════════════════════════
//  ring_perf_m6b.c — HEXA-DDP DDP-M6b: WAN THROUGHPUT of the M6 ring all-reduce.
//
//  DDP-M6 (#2899/#2900) proved the 2-node ring all-reduce crosses a real WAN
//  node boundary (vast PL<->UA, public-IP TCP) BYTE-EXACT. M6 was a CORRECTNESS
//  proof only — byte-eq is latency-independent, so it deliberately did NOT
//  measure throughput.
//
//  M6b CHARACTERIZES THE PERF of that exact transport. Same canonical ring
//  schedule (2(N-1) steps, chunk_start partition, parity send/recv ordering) as
//  M1/M3/M5/M6 — ring_tcp_m6.c byte-for-byte — but instrumented to MEASURE:
//
//    (1) RTT floor      — small-message ping-pong round-trip (latency floor).
//    (2) all-reduce BW  — achieved bandwidth (GB/s) as message size S sweeps
//                         (1KB .. 256MB of FP64 payload), repeated R times,
//                         median wall reported.
//    (3) crossover      — the size where the transfer flips from latency-bound
//                         to bandwidth-bound (where BW stops rising ~linearly).
//    (4) saturation     — the effective GB/s ceiling at the largest sizes.
//
//  HONEST (g5): this is COMMODITY WAN TCP between two rented pods — high RTT
//  (cross-country tens of ms), so small messages are latency-bound (terrible
//  effective BW) and only large messages approach the link bandwidth. We report
//  the REAL measured curve, the RTT, and the saturation size. NOT a datacenter
//  / RDMA number. NOT a correctness claim (M6 owns that).
//
//  Bytes moved per all-reduce: the ring moves 2(N-1) chunks of ~S/N each.
//  For N=2 that is 2 chunks of S/2 == S elements each way == one S-element
//  payload sent and one received per rank. We report:
//    payload_bytes = S * sizeof(double)            (the user-visible vector)
//    wire_bytes    = 2*(N-1) * (S/N rounded) * 8   (actual bytes on the wire)
//  and BW two ways: algo_BW = payload_bytes/wall (the metric users care about)
//  and wire_BW = wire_bytes/wall (raw link utilisation). For N=2 both ≈ S*8.
//
//  Build:  cc -O2 -o ring_perf_m6b ring_perf_m6b.c -lm
//  Run (2 hosts), e.g.:
//    rank1$ ./ring_perf_m6b --rank 1 --np 2 --listen 0.0.0.0:5701 \
//                           --succ <A_ip>:5700 --reps 11 --ping 50
//    rank0$ ./ring_perf_m6b --rank 0 --np 2 --listen 0.0.0.0:5700 \
//                           --succ <B_ip>:5701 --reps 11 --ping 50
//  Both ranks sweep an identical built-in size ladder and print a table.
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
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>

static void die(const char* m){ perror(m); exit(2); }

// ── optional explicit TCP socket buffer (window) size; 0 = OS default. ──────
//    Over a high-RTT WAN the bandwidth-delay product is large, so the default
//    socket buffer caps the in-flight window and throttles throughput. Setting
//    SO_SNDBUF/SO_RCVBUF lets us probe the TCP-window effect (finding 4).
static int g_sockbuf = 0;
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

// ── chunk boundaries: identical to M1/M3/M5/M6 ring_chunk_start ─────────────
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
    apply_sockbuf(ls); // inherited by accepted socket; set before listen
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
        apply_sockbuf(cs); // set before connect so the window is honored
        if (connect(cs,(struct sockaddr*)&a,sizeof a)==0){
            int one=1; setsockopt(cs,IPPROTO_TCP,TCP_NODELAY,&one,sizeof one);
            fprintf(stderr,"[rank] connected succ %s\n",hostport);
            return cs;
        }
        close(cs); usleep(200000);
    }
    fprintf(stderr,"connect %s timed out\n",hostport); exit(2);
}

// ── one ring all-reduce over the two ring sockets (host-mem FP64). Returns
//    wall seconds for the whole all-reduce. Schedule == M6 exactly.
static double one_allreduce(int rank, int N, long S, double* x, double* stage,
                            int sock_succ, int sock_pred){
    double t0 = now_s();
    #define DO_STEP(sc, rc, add) do {                                          \
        long s_st=chunk_start(S,N,(sc)), s_sp=chunk_start(S,N,(sc)+1);          \
        long r_st=chunk_start(S,N,(rc)), r_sp=chunk_start(S,N,(rc)+1);          \
        size_t s_n=(size_t)(s_sp-s_st)*sizeof(double);                         \
        size_t r_n=(size_t)(r_sp-r_st)*sizeof(double);                         \
        if (rank % 2 == 0){                                                    \
            if (s_n && sendall(sock_succ, x+s_st, s_n)) die("send");           \
            if (r_n && recvall(sock_pred, stage+r_st, r_n)) die("recv");       \
        } else {                                                              \
            if (r_n && recvall(sock_pred, stage+r_st, r_n)) die("recv");       \
            if (s_n && sendall(sock_succ, x+s_st, s_n)) die("send");           \
        }                                                                     \
        if (r_n){                                                             \
            if (add) for(long i=r_st;i<r_sp;i++) x[i]+=stage[i];                \
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

// ── ping-pong RTT: rank0 sends a tiny token to succ, rank1 echoes it back via
//    its succ socket (the ring is a 2-cycle, so rank1's succ == rank0's pred).
//    Measures wall for a full round trip; median of `pings` reported.
static double measure_rtt(int rank, int N, int sock_succ, int sock_pred,
                          int pings){
    if (N != 2) return -1.0; // RTT ping defined for the 2-cycle here
    unsigned char tok = 0xA5;
    double* samp = (double*)malloc((size_t)pings*sizeof(double));
    int nsamp = 0;
    for (int p=0; p<pings; p++){
        if (rank == 0){
            double t0 = now_s();
            if (sendall(sock_succ, &tok, 1)) die("ping send");
            if (recvall(sock_pred, &tok, 1)) die("ping recv");
            samp[nsamp++] = (now_s() - t0) * 1e3; // ms
        } else {
            // echo: receive from pred, bounce to succ
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

int main(int argc, char** argv){
    int rank=-1, N=-1, reps=11, pings=50;
    long single=0;          // if >0, sweep only this single S (large-size probe)
    const char *listen_hp=NULL, *succ_hp=NULL;
    for (int i=1;i<argc;i++){
        if(!strcmp(argv[i],"--rank")) rank=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--np")) N=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--reps")) reps=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--ping")) pings=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--single")) single=atol(argv[++i]);
        else if(!strcmp(argv[i],"--sockbuf")) g_sockbuf=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--listen")) listen_hp=argv[++i];
        else if(!strcmp(argv[i],"--succ")) succ_hp=argv[++i];
        else { fprintf(stderr,"unknown arg %s\n",argv[i]); return 2; }
    }
    if(rank<0||N<2||!listen_hp||!succ_hp){
        fprintf(stderr,"usage: --rank R --np N --listen H:P --succ H:P "
                       "[--reps n] [--ping n]\n");
        return 2;
    }
    fprintf(stderr,"[rank %d/%d] listen=%s succ=%s reps=%d pings=%d\n",
            rank,N,listen_hp,succ_hp,reps,pings);

    int sock_succ=-1, sock_pred=-1;
    if (rank % 2 == 0){ sock_succ=connect_succ(succ_hp); sock_pred=listen_one(listen_hp); }
    else              { sock_pred=listen_one(listen_hp); sock_succ=connect_succ(succ_hp); }

    // ── (1) RTT floor ───────────────────────────────────────────────────────
    double rtt_ms = measure_rtt(rank, N, sock_succ, sock_pred, pings);
    if (rank == 0)
        printf("RTT_PING median_round_trip_ms = %.4f  (over %d pings, 1-byte)\n",
               rtt_ms, pings);

    // ── size ladder: FP64 element counts S. payload = S*8 bytes. ────────────
    //    1KB .. 256MB. Each S chosen so S*8 hits the named payload.
    long ladder[] = {
        128,        // 1 KB
        256,        // 2 KB
        512,        // 4 KB
        1024,       // 8 KB
        2048,       // 16 KB
        4096,       // 32 KB
        8192,       // 64 KB
        16384,      // 128 KB
        32768,      // 256 KB
        65536,      // 512 KB
        131072,     // 1 MB
        262144,     // 2 MB
        524288,     // 4 MB
        1048576,    // 8 MB
        2097152,    // 16 MB
        4194304,    // 32 MB
        8388608,    // 64 MB
        16777216,   // 128 MB
        33554432,   // 256 MB
    };
    int nL = (int)(sizeof(ladder)/sizeof(ladder[0]));
    // single-size probe: replace the ladder with one S (large-size BW ceiling).
    long single_arr[1];
    if (single > 0){ single_arr[0]=single; nL=1; }
    long* L = (single > 0) ? single_arr : ladder;
    #define LAD(k) (L[(k)])

    if (rank == 0){
        printf("# DDP-M6b WAN all-reduce throughput sweep (N=%d, reps=%d, sockbuf=%d, median)\n", N, reps, g_sockbuf);
        printf("#  S_elems   payload_B   wire_B    median_s      algo_GB/s   wire_GB/s\n");
    }

    long maxS = LAD(nL-1);
    double* x     = (double*)malloc((size_t)maxS*sizeof(double));
    double* x0    = (double*)malloc((size_t)maxS*sizeof(double));
    double* stage = (double*)malloc((size_t)maxS*sizeof(double));
    if(!x||!x0||!stage) die("malloc");
    for (long i=0;i<maxS;i++)
        x0[i] = (double)(((long)rank*1000003L + i*7L + 1) % 9973) - 4096.0;

    double* samp = (double*)malloc((size_t)reps*sizeof(double));

    for (int li=0; li<nL; li++){
        long S = LAD(li);
        // wire bytes for N=2: each step moves one chunk (~S/N elems); 2(N-1) steps.
        // Sum the actual chunk sizes used by the schedule.
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

        // warm-up once, then timed reps. Reset x from x0 each rep.
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

    free(x); free(x0); free(stage); free(samp);
    close(sock_succ); close(sock_pred);
    return 0;
}
