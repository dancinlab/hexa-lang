# json_object_delete + json_object_keys — 이미 main 에 머지됨 (no-op cycle)

**Status**: NO-OP — 요청된 작업이 이미 origin/main 에 머지되어 추가 구현 없음.
**Provenance**: pool CLI hexa port (`dancinlab/pool` bin/pool.hexa) 풀-fix 사이클
지시 (2026-05-24).
**Precondition**: 인박스 dup-race precheck (`feedback_inbox_dup_race_precheck`)
— filing 은 멱등·싸지만 fix 사이클이 비쌈, 사이클 시작 전 활성 mainline 이
이미 해결했는지 grep 게이트 먼저.

---

## 조사 결과

요청된 두 함수 (`json_object_delete`, `json_object_keys`) 그리고
보너스 `json_object_has` 까지 **세 함수 전부 이미 stdlib/alloc/json_object.hexa
canonical 모듈에 구현+머지** 상태였다.

### 인박스 패치 노트 자체 cross-check

`archive/patches/json-object-delete-missing.md` 의 frontmatter:

```
> Status: fixed — json_object_delete + json_object_keys landed
```

§"Resolution (2026-05-23)" 에 이미 closure record 가 작성되어 있음:

- `json_object_keys(obj) -> [string]` — 이미 존재 (gap 보고 이전).
- `json_object_has(obj, key) -> bool` — 추가됨.
- `json_object_delete(obj, key) -> obj` — 추가됨; SAME map reference 반환
  (mutated in place), `json_object_set` 의 in-place idiom 미러. key 부재
  또는 obj 가 map 이 아닐 때 no-op.

### git 히스토리

```
$ git log --all --oneline -- stdlib/alloc/json_object.hexa
143c9570 feat(stdlib/json_object): json_object_delete + json_object_has (no regen) (#439)
6ccf3fd0 feat(stdlib/json_object): json_object_delete + json_object_has (no regen)
f4e9e56e feat(stdlib): F1 — extract stdlib/core/ + stdlib/alloc/ (Option C)
```

### PR 머지 상태

```
$ gh pr view 439 --json state,mergedAt,title
{
  "state":     "MERGED",
  "mergedAt":  "2026-05-23T09:47:08Z",
  "title":     "feat(stdlib/json_object): json_object_delete + json_object_has (no regen)",
  "url":       "https://github.com/dancinlab/hexa-lang/pull/439"
}
```

### 실제 구현 (stdlib/alloc/json_object.hexa L85-88, L127-130, L142-145)

```hexa
// Keys as str array. Non-map → [].
pub fn json_object_keys(obj) {
    if type_of(obj) != "map" { return [] }
    return dict_keys(obj)
}

// Key present (non-map → false). Mirrors json_object_get but boolean.
pub fn json_object_has(obj, key: string) -> bool {
    if type_of(obj) != "map" { return false }
    return has_key(obj, key)
}

// Remove a key from a JSON object. Returns the SAME map reference (mutated
// in place), mirroring json_object_set. No-op if the key is absent or obj
// is not a map. Delegates to the runtime map_remove primitive.
pub fn json_object_delete(obj, key: string) {
    if type_of(obj) != "map" { return obj }
    return map_remove(obj, key)
}
```

설계 노트: signature 가 ask 의 `-> bool` 가 아닌 `-> obj` 로 들어왔는데,
이는 `json_object_set` 의 in-place idiom 과 일치시키기 위함. existed/not-existed
신호가 필요한 caller 는 `json_object_has` 를 delete 전에 호출하면 됨.

## 다음 액션

1. **인박스 패치 archive 후보**: `archive/patches/json-object-delete-missing.md`
   는 Status "fixed" + Resolution 섹션이 이미 채워져있어, archive 디렉토리로
   이동시켜도 됨. 본 사이클에서는 건드리지 않음 (archive 정책 별도).
2. **pool CLI port 측면**: `dancinlab/pool` bin/pool.hexa 의 `pop("clean", None)`
   / `pop("description", None)` 워크어라운드 (default 값 재할당) 를 이제
   `json_object_delete` 로 전환 가능. 본 cycle scope 밖 (sister repo).
3. **lesson**: 사용자 지시가 "구현해" 인 경우에도 inbox patch 의 Status / git log
   먼저 grep 으로 dup-race precheck.

## 본 사이클 산출물

- 코드 변경: **없음** (강제 구현 금지 정책 적용).
- 본 notes 파일 (발견 finding).
- PR: **생성 안 함** (no-op).
