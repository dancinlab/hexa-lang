# cloud rent vast — "no matching offers — []" while vastai HAS offers

**증상**: `hexa cloud rent vast --gpu 1 [--query ...]` 가 항상 `search offers: no matching offers — []` 반환(2회). 그러나 같은 계정 `vastai search offers 'rentable=true num_gpus=1 dph_total<1.2 cuda_max_good>=12.0 gpu_ram>=10'` 는 RTX_3060/3050/GTX_1080 등 다수 offer 반환.

**추정**: cloud rent 의 vast 검색 필터가 과도하게 좁음(기본 query/이미지/reliability/datacenter 제약?) → --query 를 줘도 매칭 0. vastai 직접 search 와 cloud rent 의 query 매핑 불일치 가능.

**요청**: cloud rent vast 의 (a) 기본 query 완화 또는 (b) --query 패스스루를 vastai DSL 그대로 전달 + (c) `cloud rent --selftest`/`--dry-run` 에 "matched N offers" 진단 출력. anima GPU decode 실측(#2386 검증)이 이 때문에 막힘 — 재현: 위 명령.

**우회 현재**: 없음(raw vastai create 는 ssh-orchestration 비용리스크로 보류). cloud rent 가 매칭하면 즉시 진행.
