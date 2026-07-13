# axis-③ 다음 프론티어 우선순위 플랜 (워크플로우 wf_84d18885·2026-07-11)

## Synthesize 플랜

확인 완료 — 평가 사실관계 grounded (origin/main HEAD=8c56778ac #4852, CHANGELOG=30줄·2026-07-09 정지 → #4847/#4849/#4851/#4852 4건 누락 CONFIRMED, exempt=220줄 존재).

---

## (1) 우선순위 랭킹 — 북극성(clang-0 self-host 완성) 완성도+표준경로 順

**1위 · Lane 2 (L2 C-fallback 제거 / darwin native 라우팅)** — 유일하게 북극성 *완성 축* 위에 있는 레인. clang-0 = 마지막 C-transpile 의존 제거이고, compiler/main.hexa(머신 SSOT)는 이미 3-타깃 native writer·C-transpile 전무. 갭은 순전히 소비 드라이버(self/main.hexa)가 darwin을 그 native 경로로 라우팅 안 하는 것뿐. darwin은 릴리스 필수 타깃 + mini 자신의 플랫폼 → 단일 최대 C-fallback 소비처를 닫는 것이 **가장 완성도 높은 표준경로 스텝**. 전체는 XL/high지만 rung-1(darwin 라우팅)은 잘 스코프된 M.

**2위 · Lane 1 (ast_to_hir R2 `_pop_frame` n_live)** — *인에이블러*. self-emit 202s의 70%가 lower이고, R2는 잔여 O(idents×M)의 정확한 근원(:1147-1170 element-copy 루프)을 정면 타격. byteeq-neutral·default-OFF 머지 가능. 북극성 native 경로를 실사용 가능 속도로 만드는 작업이라 2위(완성 축 자체는 아니고 그 경로를 shippable하게 함).

**3위 · Lane 4 (세션 감사 / exempt prune)** — self/*.c==∅ 심볼 플로어(=self-host 불변식)를 지키는 C-1 census의 teeth를 복원. 138 stale exempt는 현재 blind-spot(향후 매핑 제거를 residual이 가려 RED 못 잡음). trivial·local·low. 자기호스트 플로어 직결 가드라 Lane 3보다 위.

**4위 · Lane 3 (own-link perf 후속)** — 대부분 measure-first이고, findings가 잔여(GOT 3-스캔·census tripwire·_aef dedupe)를 **inert로 추정**(106s PASS 근거·n_got/GOT-reloc 미계측). 투기적 이득 + opt-in self-emit 경로(shipping/북극성 무영향)라 완성 축 최하위. 단 내부 CHANGELOG loose-end은 레인 우선순위와 무관하게 즉시 분리 처리.

---

## (2) 즉시 착수 추천 1개 — Lane 2 rung-1 (darwin native build/run 라우팅)

구현은 mini-로컬 가능, 검증만 pool-gated(darwin arm64 byteeq). 첫 3스텝:

1. **origin/main 정독·정확 배선 확인**: `git show origin/main:compiler/main.hexa`로 arm64-darwin native emit 경로(:1012 pack_lir+serialize Mach-O writer)+own-link/ld 배선, `git show origin/main:self/main.hexa`로 cmd_build leg-B(:3541)·cmd_run(:4548)의 Linux x86_64/aarch64 uname 게이트 정확 조건 확인.
2. **게이트 확장(default-OFF 플래그)**: `#ifndef`/env(예 `HEXA_BUILD_NATIVE_DARWIN`, default-OFF)로 arm64-apple-darwin일 때 compiler/main.hexa Mach-O writer+ld 경로 라우팅 추가. **emit/link 실패 시 기존 hexat→.c→clang fallback 보존**(안전망 유지 — 이게 release-integrity 핵심).
3. **default-OFF 머지 → pool 실측 게이트**: darwin arm64 pool에서 byteeq-real(gen3≡gen4 + 컴파일 프로그램 byte-eq) + install.sh shipping smoke GREEN 확인 후에만 flip. mini 로컬 불가(compute-gated).

착수 전 (4)의 두 로컬 loose-end을 먼저 처리(분 단위).

---

## (3) effort / risk / byteeq-gated 요약표

| 순위 | Lane | effort | risk | byteeq-gated | mini-로컬 가능? | 북극성 관계 |
|---|---|---|---|---|---|---|
| 1 | L2 C-fallback (darwin rung-1) | XL 전체 / rung-1=M | high | 예 (pool) | 구현 O·검증 X | **완성 축** |
| 2 | ast_to_hir R2 `_pop_frame` | M | med | 예 (pool) | 구현 O·검증 X | 인에이블러 |
| 3 | 세션감사 exempt prune | S | low | 예(mild·advisory) | O (전부) | 플로어 가드 |
| 4 | own-link perf 후속 | S | low | 아니오(opt-in) | 계측 X·CHANGELOG O | 무영향 |

측정없는 추정 명시:
- Lane 1 배수 미측정: pop만 제거(배수↓) vs pop+define ×M 동시 제거(배수↑)는 `_define_in_scope`(:1173) COW 비용이 O(M)인지 amortized O(1)인지 미측정에 달림 — 실측 전 미확정.
- Lane 3 잔여 inert = **추정**: n_got/GOT-reloc 규모 미계측, 106s PASS만 근거.
- "90min→106s" 비율 = 알고리즘 절감 + RAM-headroom(swap-thrash 해소) 혼재 가능(추정) — pre-fix 동일 60GB pod baseline 부재. 정확 배속 공표 필요시에만 재측정(유료 pod + >90min cost-trap → 권장 SKIP).

---

## (4) 즉시 처리할 세션 loose-end (전부 mini-로컬·trivial)

1. **CHANGELOG.jsonl 재기록 (Lane 3-d · 확정)** — origin/main 30줄·2026-07-09 정지 검증됨. `#4847`(argv 배선)·`#4849`(comment fix)·`#4851`(own-link 1024-bucket)·`#4852`(exit-flush guard) **4건 누락**. L0/changelog-gate 규율 위반 → 4엔트리 append(`/changelog add`). 유일 must-do 거버넌스 항목.

2. **exempt prune (Lane 4-top_next)** — `tool/symcensus_lint.sh --list`이 뱉는 138 STALE 엔트리를 `tool/symcensus_exempt.txt`(220줄)에서 프룬 → C-1 blind-spot 138 제거. advisory이므로 byteeq 무관. 프룬 후 STALE-advisory의 hard-fail 승격 + symcensus_lint를 `selfhost_gates_summary.sh`(현재 grep 0hit·미호출)에 편입해 required check로 올리는 것은 별도 후속(가드 teeth 강화).

두 건 모두 lane 실착수(위 2)의 pre-work로 먼저 클리어 권장. 나머지 감사 항목((b) const_void 정합·(c) argv/own-link whack-a-mole 종결·(d) genuine 미매핑=60)은 회귀 없음·의도적 exempt로 확인되어 no-action.

## 4-lane 평가 원본

### ast_to_hir perf — R2 _pop_frame n_live · R3 map heapify heap_clean
- state: lower_ast_to_hir는 rung#1a(#4797 lookup bucket)+rung#1b(#4798 array heap_water) 후에도 self-emit 202s의 70%(summer 141.7s·vast 55.8s)로 여전히 #1 벽. 잔여 O(idents×M)의 유력 근원은 #4798이 못 덮는 `_pop_frame`의 명시적 element-copy 루프(compiler/lower/ast_to_hir.hexa:1147-1170, per-pop O(start)≈O(M)). R2(n_live)는 이걸 정면 겨냥해 well-targeted, R3(map heap_clean)는 #4798의 map 미러지만 lower 병목 기여도가 미측정·speculative.
- top_next: R2 구현: ast_to_hir.hexa:1120 LowerScope에서 bindings 필드를 제거(또는 module-frame용으로 동결)하고 locals를 전역 `_lr_locals` 버퍼+scope의 `n_live: i64`로 전환 — _pop_frame(:1147)은 n_live=frame_start만 되감고(copy 제거), _define_in_scope(:1171)은 _lr_locals[n_live] overwrite/append, _lookup_in_scope(:1255)은 _lr_locals[0..n_live) backward+버킷. #ifndef 플래그로 default-OFF 머지→byteeq-real 3-target GREEN 후 flip. summer 141.7s baseline 대비 pool 실측 필수.
- effort=M risk=med byteeq_gated=True
- blockers: flip 게이트=byteeq-real 3-target(gen3≡gen4 + 컴파일된 프로그램 byte-eq) GREEN 필요 — pool/CI compute-gated, mini 로컬 불가 · 예상배수는 추정: _define_in_scope(:1173 `let mut bindings = sc.bindings; bindings.push`)가 COW로 O(M) copy인지 amortized O(1)인지 미측정 — O(M)이면 R2가 pop+define 양쪽 ×M 동시 제거(배수↑), 아니면 pop만(배수↓). 실측 전엔 미확정 · R3 benefit-to-lower 미측정: lower의 지배 컨테이너는 array(_lr_ast_gbinds 버킷·bindings)지 map이 아님 — R3는 일반 런타임 O(n²) 미러지 lower 병목 직결 근거 없음
- findings:
  - R2 타겟 정당: _pop_frame(ast_to_hir.hexa:1147-1170)은 매 block/match-arm/fn pop마다 `while i<start { new_bindings.push(sc.bindings[i]) }` 로 module-frame prefix(start≥gbound≈2.5-5k)를 통째 재복사 → per-pop O(M), pops≈O(statements) → O(idents×M). #4798 heap_water(runtime_core_emit.hexa:5748-5766)는 heapify만 덮고 이 명시적 copy는 안 덮음 → 진짜 잔여 O(idents×M). n_live(전역버퍼+논리길이)는 pop을 O(depth)로 붕괴.
  - R2 byte-eq-neutrality 근거 견고: module pre-pass(:2736-2769)와 _lr_ast_prime_globals 버킷은 그대로 두고 locals만 전역버퍼로 이전. 임의 lookup 시점의 가시 바인딩 집합=module 버킷(불변)+locals[0..n_live) 삽입순(불변), backward-scan 순서 동일, next_index(DefId) threading 보존(:1179·pop이 next_index preserve :1167) → 모든 _lookup이 동일 LowerBinding 반환 → 동일 HExpr DefId → byte-eq NEUTRAL.
  - R2 aliasing-soundness는 성립하나 byteeq-real이 안전망: 전 walk이 strict DFS single-thread(block :2104-2117·match arm :2218-2293 모두 `new_sc=r.sc`/`new_sc=_pop_frame(arm_sc)` 로 선형 threading), lookup이 DefId를 즉시 HExpr에 baked(:1848-1855 `def:def`)해 이후 슬롯 overwrite가 기emit HExpr 손상 불가. match arm 간 공유는 arm2 define이 arm1의 죽은 슬롯[k..)만 overwrite → sound. 단 '스코프 값을 sibling mutation 이후 read'하는 비선형 사용이 하나라도 있으면 전역버퍼 모델이 corruption — 감사상 없음이나 이 판정을 byteeq-real 3-target diff가 최종 검증해야 함(default-OFF 선머지 필수).
  - 정확 수정지점(R2): (a) struct LowerScope:1120에 n_live 추가·bindings 제거, (b) 전역 `let mut _lr_locals:[LowerBinding]=[]` 신설+entry(:2730 `_lr_ast_gnames=[]` 옆)에서 리셋, (c) _push_frame:1136→frame_starts.push(sc.n_live), (d) _pop_frame:1147→n_live=start만·copy루프 삭제, (e) _define_in_scope:1171/_define_with_def:1183→_lr_locals[n_live] overwrite-or-push, (f) _lookup_in_scope:1255→_lr_locals[0..n_live) backward. pre-pass의 module_sc.bindings 경로는 module-frame 전용으로 분리 유지.
  - R3는 array→map 정직한 미러지만 별개 carrier·미측정: heap map arm(runtime_core_emit.hexa:5710-5729 `else if HX_MAP_TBL(v)`)이 arena_return마다 전 non-empty slot을 재-heapify → 지속 map의 O(returns×slots). heap_water(append-only index)는 map엔 무의미하므로 R3는 HexaMapTable에 boolean `heap_clean` 비트가 정답: heapify 완주 시 set, 임의 hmap_set/grow(arena값 저장 가능 경로)에서 clear. 구현=3-carrier 동기(runtime.h:65 HexaMapTable + runtime_core_emit.hexa:5710 walk + hmap_set/grow store-barrier)+#ifndef 게이팅 → effort L. soundness burden=store-barrier가 arena값 저장 전 경로를 100% clear해야 함(누락 시 dangling arena ptr corruption); byteeq+ASAN smoke로 검증. lower 병목 기여 미증명이라 R2 후순위.

### L2 · axis-① C-fallback 제거 (hexa_cc.c / C-transpile delegate)
- state: axis-③ end-to-end(self-emit .o+RUN+own-link)는 켜졌고 native 경로가 byte-id self-host을 실증하지만, hexa_cc.c는 아직 whole-removal 불가. 이유: shipped self/main.hexa의 native build/run 경로가 Linux x86_64/aarch64 전용이라 darwin(필수 릴리스 타깃)·cross-target·--shared·--c-only·emit-실패 fallback·cold-clone bootstrap이 전부 C-transpile을 유일 경로로 계속 의존한다. compiler/main.hexa(머신 SSOT)는 이미 C-transpile 전무·3타깃 native emit인데, 소비 드라이버(self/main.hexa)가 darwin을 그 native 경로로 라우팅하지 않는 게 핵심 갭.
- top_next: self/main.hexa:3541 (cmd_build)와 :4548 (cmd_run)의 Linux-전용 uname 게이트를 arm64-apple-darwin까지 확장해, compiler/main.hexa가 이미 가진 native Mach-O writer(backend=native default-flip + pack_lir/serialize)+own-link/ld로 darwin build/run을 라우팅. darwin byteeq + install.sh shipping smoke GREEN 게이트. 단일 최대 C-fallback 소비처(darwin)를 닫는다.
- effort=XL risk=high byteeq_gated=True
- blockers: darwin(arm64-apple-darwin) 갭: cmd_build leg-B(self/main.hexa:3541) + cmd_run native-first(:4548) 둘 다 Linux x86_64/aarch64 uname 게이트 — darwin shipped build/run은 여전히 hexat→.c→clang. mini 자체가 darwin이고 릴리스는 3타깃(darwin arm64 포함)이라 릴리스-무결 직결 블로커 · cross-target(--target=): 두 native 경로 모두 --target을 refuse → zig cc C-transpile 유일 경로 · --shared: native codegen(RFC070 G7-A K2 PIC GOT-load)은 있으나 링크는 clang -shared. own/ld -shared 링크 경로 부재 · --c-only: 기능 정의가 C 방출 — C-transpile 제거 시 이 surface 폐기/재설계 필요(외부 빌드시스템 소비자) · emit-실패 안전망: 현 native 경로들이 @lazy niche·미지원 construct·emit-fail 시 C-transpile로 fall-through를 안전망으로 사용. hexa_cc.c 제거 = 안전망 소멸 → 3타깃 full-corpus 0-gap 선증명 필수 · bootstrap: resolve_or_bootstrap_hexat + cmd_cc + `hexa cc --regen`이 cold-clone seed로 hexa_cc.c를 SSOT(codegen_c.hexa)에서 재생성 — prebuilt native compiler seed로 대체 전엔 제거 불가
- findings:
  - hexa_cc.c는 tracked C가 아님(.gitignore:323, self/*.c==∅ 유지). '제거' = git rm이 아니라 (a)생성 SSOT 삭제 self/codegen_c.hexa·codegen_c_min.hexa·build_c.hexa·hexa_build.hexa·run_build.hexa + (b)소비 드라이버 사이트 제거 cmd_cc·regen pipeline·resolve_or_bootstrap_hexat·cmd_build/cmd_run의 C-transpile 브랜치. runtime.c도 동일하게 generated(.gitignore:312)
  - compiler/main.hexa(=aprime_cc/native compiler, 머신 SSOT)에는 C-transpile이 전무. --emit=obj/exec가 3타깃 native ELF/Mach-O writer로 직행(arm64-darwin :1012 pack_lir+serialize, arm64-linux :1041, x86_64-linux :1072 pack_lir_x86_64+serialize_elf_x86_64), backend=system은 as/ld fallback일 뿐 C 아님. axis-③ own-link(--linker=hexa)가 clang+binutils-free 증명
  - REPLACED(native, no C): `hexa run` Linux x86_64/arm64 기본(self/main.hexa:4548, r26 default-ON) + HEXA_LINK_HEXA=1 완전 own-link(clang+ld-free, x86_64-linux); `hexa build` Linux x86_64/aarch64 기본(HEXA_BUILD_NATIVE default-ON, :3541 leg-B aprime --emit=obj+ld, hexat/clang 0회)
  - STILL C-FALLBACK: darwin build/run(Linux 게이트 밖 → hexat→.c→clang), cross-target(--target= → zig cc), --shared(clang -shared), --c-only(C 방출 자체), 그리고 모든 native emit/link 실패 시 delegate-fallback(cmd_build:3576+ hexat transpile, cmd_run clang `hexa build` loop). 안전망이 곧 C-transpile
  - 제거 순서(release-safe): 1)darwin native 라우팅(:3541/:4548 게이트 확장→ compiler/main.hexa Mach-O writer) 2)cross-target native emit+link(zig 대체) 3)--shared own/ld -shared 4)--c-only 폐기/재설계 5)emit-fail C fallback 제거(3타깃 full-corpus 0-gap 선증명 후) 6)prebuilt native compiler를 cold seed로→ regen pipeline+cmd_cc+codegen_c*.hexa 삭제
  - release-integrity 리스크 HIGH: C-transpile은 현재 (i)유일 darwin 빌드 경로 (ii)유일 cross-target 경로 (iii)유일 --shared/--c-only 경로 (iv)범용 emit-fail 안전망 (v)cold-clone bootstrap seed. 5개 커버 전 제거 = user-facing shipping path(darwin+cross+fallback) 파손 → CLAUDE.md '자기호스트 게이트 위해 user-path 파손 금지'·'only-x86-green 승격 금지' 직접 위반

### own-link perf follow-up (#4851 후속 · compiler/emit/elf_x86_64.hexa)
- state: origin/main(adb39cbba #4851 + 8c56778ac #4852) 반영 확인. #4851은 def-index만 1024-bucket(_ldx_hash :1598)로 이식했고, 잡은 벽은 오직 per-reloc census(:1872)/resolve(:2166)의 O(defs) 선형스캔(95k reloc × ~5만 def_names)이다. GOT 3사이트·census tripwire·_aef 아카이브 시드는 손대지 않았다. 106s PASS는 clean 60GB vast pod 1회 측정이고 pre-fix 동일-pod baseline은 없다.
- top_next: (a) 판정 게이트: self-emit own-link에서 n_got(got_syms)와 GOT-kind reloc 개수를 1회 계측(eprintln 카운터 or pod strace). GOT COLLECT(:1799)·FILL(:2201)·EXTENSION(:1964) 3개 선형 O(got_relocs×n_got) 스캔이 #4851 이후 유일하게 규모 미측정인 잔여 O(N×M)이며 다음 벽 후보. 소규모면 inert 확정, 대규모면 _ldx 미러로 버킷화(effort S).
- effort=S risk=low byteeq_gated=False
- blockers: CHANGELOG.jsonl 드리프트(item d, 확정): origin/main CHANGELOG는 30줄·마지막 2026-07-09에서 멈춤. #4851 커밋이 'CHANGELOG re-added post-merge'를 약속했으나 실제 미반영(#4849/#4851/#4852 전부 누락). CLAUDE.md L0/changelog-gate 규율 위반 → 재기록 필요.
- findings:
  - (a) GOT 잔여선형 [elf_x86_64.hexa:1799 COLLECT dedup·:2201 FILL·:1964 EXTENSION]: #4851 버킷 미적용. 단 per-got×defs가 아니라 per-GOT-reloc×n_got(got_syms) — 애초에 50k-def 벽과 무관(defs를 스캔한 적 없음). COLLECT(:1780)은 osn 캐시(:1838)보다 앞서 실행돼 이름을 char-by-char 재구성(O(L^2))까지 함. 규모=n_got 미측정(:2191 주석상 g<id> module-global GOTPCREL 케이스 존재하나 106s PASS로 보아 현재 modest 추정). 효과=계측 후 조건부, effort=S(버킷화 + osn build를 COLLECT 앞으로 재배치해 O(L^2) 제거).
  - (b) census tripwire FORWARD probe [elf_x86_64.hexa:1911-1919]: while _rdi<len(runtime_defs) 안에서 'hexa_array_'+dnm 등 4개 접두문자열을 매 _rd 반복마다 재concat → O(n_dyn × runtime_defs × 4). distinct UND 이름당 1회(dfi<0)라 n_dyn(libc floor ~수백)으로 bounded → 벽 아님. fix=4개 접두문자열을 루프 밖 dnm당 1회 계산+순수비교. effort=S, 효과=작음.
  - (c) _aef 시드 dedupe O(N^2) [elf_x86_64.hexa:3499 _aef_all_member_defs · 3534/3549/3573/3591/3601 archive_extract_fixpoint]: _aef_has(:3468 선형)로 삽입마다 O(N) → O(N^2). 단 N=runtime.a exported GLOBAL/WEAK(runtime API 표면 ~수천)이지 combined 50k def_names 아님 → ~수백만 compare(초 단위), 106s 미지배 이유. fix=_ldx/_symh 버킷 미러. effort=S~M, 효과=modest.
  - (d) CHANGELOG 재기록 [CHANGELOG.jsonl, 확정 갭]: origin/main 30줄·마지막 2026-07-09. #4851 부수커밋이 append-conflict로 엔트리 drop 후 'post-merge 재추가' 약속했으나 미이행. #4849/#4851/#4852 3건 누락. 유일한 must-do 거버넌스 항목·local·trivial. effort=S, 효과=규율준수(perf 무관).
  - (e) fix-vs-clean-RAM baseline [verdict-integrity]: pre-fix 커밋을 동일 clean 60GB pod에서 재측정 안 함. osn 캐시 fix는 CPU뿐 아니라 per-reloc O(L^2) transient string 할당도 대폭 절감 → >90min의 일부가 swap-thrash(RAM)였을 수 있어 '90min→106s' 헤드라인 비율이 알고리즘+RAM-headroom 혼재 가능. 그러나 복잡도 감소가 구조적으로 sound하고 byteeq-neutral·opt-in(shipping 무영향)이라 정확 배속수치 공표가 필요치 않는 한 필수 아님. 필요시 pre-fix 커밋을 동일 60GB pod 재실행. effort=M + cost-trap(유료 pod+>90min) → 권장 SKIP.
  - byteeq: (a)-(c) 전부 버킷/재배치=삽입순 보존→index-only→byte-identical(#4851과 동일 논거), (d)-(e)=docs/측정. own-link은 opt-in self-emit 경로라 shipping byteeq 무영향.

### 세션 머지 감사 (axis-③ symcensus + const_void + argv/own-link, #4839-42/#4840/#4847/#4851)
- state: 6건 머지 모두 origin/main에 착지·기능 회귀 없음. 유일한 실질 loose end는 C-1 심볼센서스 exempt 리스트의 stale화: tool/symcensus_exempt.txt 198엔트리 중 138개가 #4839/#4842로 이미 mapped/covered인데 프룬 안 됨. 나머지 (b)const_void 정합·(c)RUN whack-a-mole 종결·(d)genuine 미매핑=60은 의도적 exempt로 확인.
- top_next: tool/symcensus_lint.sh --list이 뱉는 138개 STALE exempt 엔트리를 tool/symcensus_exempt.txt에서 프룬 (advisory→C-1 blind-spot 138개 제거). 프룬 후 STALE-advisory를 hard-fail로 승격 검토.
- effort=S risk=low byteeq_gated=True
- blockers: 
- findings:
  - (a) CI 배선 OK·exempt STALE — symcensus-lint은 .github/workflows/nobaseline-gate.yml:119 job으로 PR+push(compiler/tool/** 필터)마다 `bash tool/symcensus_lint.sh` 실행되어 residual!=0에서 RED. 그러나 tool/symcensus_exempt.txt 198엔트리 중 138개가 #4839(array60)+#4842(non-array137) 매핑으로 이미 covered인데 프룬 안 됨(#4841이 exempt파일을 저작할 때 #4839가 이미 매핑한 array_* 조차 나열→태생부터 stale, #4842는 매핑만 추가하고 프룬 생략). 린트는 residual=0이라 GREEN 유지하되 `138 STALE exemption` advisory만 출력.
  - (a-2) 가드무결성 약화 — 138개 stale exempt는 blind-spot: 향후 어떤 PR이 그 심볼의 _builtin_runtime_sym 매핑을 제거해도 exempt가 residual을 가려 C-1이 RED로 못 잡음. 게다가 symcensus-lint는 required check 아님 — 유일 required=selfhost-gates-summary(selfhost-gates-required.yml:25)이고 tool/selfhost_gates_summary.sh는 symcensus_lint를 호출 안 함(grep 0hit).
  - (b) #4840 const_void 정합 확인 — compiler/codegen/x86_64_linux.hexa:1424 _x86_tag_resolve가 이제 arm64 _hv_load(arm64_darwin.hexa:1664)와 완전 정합: const_str→3·const_float→1(1369/1374)·const_bool→2(1418)·const_void→4(1432)·default(const_int/untracked)→0. TAG_VOID=4는 runtime.h enum·arm64:1665와 일치. payload는 imm 0 fallthrough(=arm64 payload#0). 누락 const case·회귀 없음.
  - (c) argv/own-link RUN whack-a-mole 종결 확인 — #4846(159a4362b) 명시: 심볼맵 DRAINED(317 mapped). read_file_bytes는 이제 매핑됨(arm64_darwin.hexa:2161 →rt_read_file_bytes). is_digit은 의도적 미매핑(runtime hexa_is_digit def 부재·C-2 own-link tripwire가 net). #4847 x86 hexa_set_args는 mf.name=='main' 게이트·rdi/rsi(argc/argv) 온전·push rbp 직후 16B정렬로 정확(x86_64_linux.hexa:5618). #4851 own-link perf의 exit-stdio-flush+stale runtime.a loose end는 #4852가 세션 내 종결. 미해결 whack-a-mole 없음.
  - (c-2) C-3 dynsym 게이트 DORMANT — nobaseline-gate.yml:412 own-linked cc-self-bin dynsym UND⊆sanctioned 게이트는 skip-if-absent이고 CI 어느 스텝도 own-linked 바이너리를 HEXA_CC_SELF_BIN/build에 안 남겨 실제로 항상 skip. 실효 always-on 넷은 C-1 소스린트(비-required+stale blind-spot)+C-2 tripwire(opt-in --linker=hexa 경로만). 런타임 UND 센서스는 pod-manual, CI 강제 아님.
  - (d) 44-48 아닌 60 genuine 미매핑 — exempt−covered=60(term_*/thread_*/atomic_cell_*/pty_*/gpu_*/net-lite/getenv/panic/assert/is_digit 등 interp-only·CUDA-gated·TAG_FN carrier·identity-OK bare==runtime.a def). 회귀 아니고 의도적 exempt이나, exempt파일이 60 genuine과 138 stale을 뒤섞어 outstanding population을 198로 과대표기(실제 genuine=60).

