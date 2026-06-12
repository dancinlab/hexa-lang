// T4 — cuBLASLt heuristic introspection @D=4096 vs 2048 (TF32). Logs which algo/tile/
// split-K/stages cuBLASLt picks. NO bit-exactness change (read-only heuristic query).
#include <cublasLt.h>
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#define CK(x) do{ auto e=(x); if(e!=CUBLAS_STATUS_SUCCESS){printf("cublas err %d @%d\n",(int)e,__LINE__);exit(1);} }while(0)
#define CC(x) do{ auto e=(x); if(e!=cudaSuccess){printf("cuda err %s @%d\n",cudaGetErrorString(e),__LINE__);exit(1);} }while(0)

void probe(cublasLtHandle_t lt, int D){
  int M=D,N=D,K=D;
  cublasLtMatmulDesc_t op;
  CK(cublasLtMatmulDescCreate(&op, CUBLAS_COMPUTE_32F_FAST_TF32, CUDA_R_32F));
  cublasOperation_t tn=CUBLAS_OP_N;
  CK(cublasLtMatmulDescSetAttribute(op,CUBLASLT_MATMUL_DESC_TRANSA,&tn,sizeof(tn)));
  CK(cublasLtMatmulDescSetAttribute(op,CUBLASLT_MATMUL_DESC_TRANSB,&tn,sizeof(tn)));
  cublasLtMatrixLayout_t la,lb,lc;
  CK(cublasLtMatrixLayoutCreate(&la,CUDA_R_32F,M,K,M));
  CK(cublasLtMatrixLayoutCreate(&lb,CUDA_R_32F,K,N,K));
  CK(cublasLtMatrixLayoutCreate(&lc,CUDA_R_32F,M,N,M));
  cublasLtMatmulPreference_t pref;
  CK(cublasLtMatmulPreferenceCreate(&pref));
  size_t ws = (size_t)256*1024*1024;
  CK(cublasLtMatmulPreferenceSetAttribute(pref,CUBLASLT_MATMUL_PREF_MAX_WORKSPACE_BYTES,&ws,sizeof(ws)));
  const int NREQ=8;
  cublasLtMatmulHeuristicResult_t res[NREQ];
  int got=0;
  CK(cublasLtMatmulAlgoGetHeuristic(lt,op,la,lb,lc,lc,pref,NREQ,res,&got));
  printf("=== D=%d : %d heuristic algos returned (best-first) ===\n",D,got);
  for(int i=0;i<got;i++){
    cublasLtMatmulAlgo_t* a=&res[i].algo;
    int algoId=-1,tile=-1,stages=-1,splitk=-1,reduction=-1,swizzle=-1,cta=-1,inner=-1;
    size_t cfgsz;
    cublasLtMatmulAlgoConfigGetAttribute(a,CUBLASLT_ALGO_CONFIG_ID,&algoId,sizeof(algoId),&cfgsz);
    cublasLtMatmulAlgoConfigGetAttribute(a,CUBLASLT_ALGO_CONFIG_TILE_ID,&tile,sizeof(tile),&cfgsz);
    cublasLtMatmulAlgoConfigGetAttribute(a,CUBLASLT_ALGO_CONFIG_STAGES_ID,&stages,sizeof(stages),&cfgsz);
    cublasLtMatmulAlgoConfigGetAttribute(a,CUBLASLT_ALGO_CONFIG_SPLITK_NUM,&splitk,sizeof(splitk),&cfgsz);
    cublasLtMatmulAlgoConfigGetAttribute(a,CUBLASLT_ALGO_CONFIG_REDUCTION_SCHEME,&reduction,sizeof(reduction),&cfgsz);
    cublasLtMatmulAlgoConfigGetAttribute(a,CUBLASLT_ALGO_CONFIG_CTA_SWIZZLING,&swizzle,sizeof(swizzle),&cfgsz);
    cublasLtMatmulAlgoConfigGetAttribute(a,CUBLASLT_ALGO_CONFIG_INNER_SHAPE_ID,&inner,sizeof(inner),&cfgsz);
    printf("  [%d] algoId=%d tile_id=%d stages_id=%d split_k=%d reduction=%d cta_swizzle=%d inner_shape=%d  ws=%zuB  waves=%.2f\n",
      i,algoId,tile,stages,splitk,reduction,swizzle,inner,res[i].workspaceSize,res[i].wavesCount);
  }
  cublasLtMatmulPreferenceDestroy(pref);
  cublasLtMatrixLayoutDestroy(la);cublasLtMatrixLayoutDestroy(lb);cublasLtMatrixLayoutDestroy(lc);
  cublasLtMatmulDescDestroy(op);
}
int main(){
  cublasLtHandle_t lt; CK(cublasLtCreate(&lt));
  printf("cuBLASLt TF32 (CUBLAS_COMPUTE_32F_FAST_TF32) heuristic introspection, M=N=K=D, col-major NN\n");
  printf("NOTE tile_id/stages_id are cuBLAS-internal enums; the KEY columns are split_k & reduction (g5 bit-exactness).\n\n");
  probe(lt,2048);
  printf("\n");
  probe(lt,4096);
  cublasLtDestroy(lt);
  return 0;
}
