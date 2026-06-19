# cloud rent → "no matching offers — []" 재현, 단 src 의 vast_search_offers 직접호출은 JSON 정상

**증상**: `hexa cloud rent vast --gpu 1 --query 'cuda_max_good>=12.0 gpu_ram>=8 dph_total<1.0'`
→ `[cloud] rent vast: search offers: no matching offers — []` (재현 가능, 일시장애 아님).
그러나 같은 머신에서 `vastai search offers '<동일 eff>' -n --raw` 직접 = **64 offers**.

**진단 (v0.241.11, mini darwin-arm64)**:
- `vast_gpu_predicate("1")` = `"num_gpus>=1"` ✅ (#3671 fix 정상 반영)
- secret `vast.api_key` md5 == `~/.config/vastai/vast_api_key` md5 ✅ (인증 동일)
- `_vastai_path()` = `~/vastenv/bin/vastai` (v1.0.13); `~/.hx/bin/vastai` 도 동일 버전 → 둘 다 직접 64 offers ✅
- `_shq_local`, `_vast_build_query`(verified_only=1 → `rentable=true verified=true reliability>=0.95 <q>`) 조립 정상 ✅
- **`vast_search_offers("num_gpus>=1 cuda_max_good>=12.0 gpu_ram>=8 dph_total<1.0", 1)` 를 `HEXA_LANG=~/.hx/src hexa run` 으로 직접 호출 → JSON 64 (ok=1) ✅**
- 그러나 `hexa cloud rent`(= cloud_cli.hexa:1398 `vast_search_offers(query,1)`) → `[]` ❌

**결정적 단서**: src(`~/.hx/src/stdlib/cloud/vast.hexa`)의 `let out = exec(cmd)` 직전에 `cmd`/`out` 을
파일로 떨어뜨리는 debug 를 주입한 뒤 `hexa cloud rent` 를 실행 → **debug 파일이 빈 채로 남음**
(`/tmp/CR_cmd.txt` empty). 즉 `hexa cloud rent` 는 src 의 `vast_search_offers` 본문을 타지 않음.
반면 `hexa run <file>`(HEXA_LANG=src)은 debug 가 정상 기록되며 JSON 반환.

**가설 (미확정)**: `hexa cloud rent`(컴파일된 cloud 서브커맨드)와 `hexa run`(src 인터프리트)의
stdlib resolution/빌드가 갈려, 동일 v0.241.11 소스인데 cloud rent 경로에서만 `vast_search_offers`
가 `[]` 를 반환. self-host 컴파일 vs 인터프리트 동작 불일치 또는 cloud 명령의 내장 stdlib 스냅샷
가능성. (src 수정으로는 cloud rent 라이브 동작이 안 바뀜 — 재빌드 의존.)

**재현**:
```
vastai search offers 'rentable=true verified=true reliability>=0.95 num_gpus>=1 cuda_max_good>=12.0 gpu_ram>=8 dph_total<1.0' -n --raw   # 64
hexa cloud rent vast --gpu 1 --query 'cuda_max_good>=12.0 gpu_ram>=8 dph_total<1.0' --max-wait-sec 5   # no matching offers — []
```

**요청**: (a) cloud rent 의 vast_search_offers 가 [] 반환하는 실제 원인(빌드/내장 stdlib vs src 불일치) 규명,
(b) 가능하면 vastai 빈 응답에 대한 search 재시도(retry) 로 robustness 보강. anima GPU 실측(#2386)이
cloud rent 로 막혀 raw vastai 로 우회 중.
