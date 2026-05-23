# gap: no `json_object_delete(obj, key)` — can't remove a key from a JSON object

> Date: 2026-05-23
> Severity: low (cosmetic — values can be re-set, just not removed)
> Reporter: pool CLI hexa port (`dancinlab/pool` bin/pool.hexa)
> Status: fixed — json_object_delete + json_object_keys landed

## Gap

`stdlib/alloc/json_object` has `json_object_set` / `_get_str` / `_get_bool` / `_get_array`
but **no delete/remove/unset**. Confirmed absent:

```
grep -noE 'json_object_(delete|remove|unset|del)[a-z_]*' self/codegen_c2.hexa self/runtime*.c
→ (nothing)
```

There is also no `json_object_keys(obj)` iterator, so a key cannot even be dropped
by rebuilding the object minus that key.

## Trigger

Porting `bin/pool` (Python) → `bin/pool.hexa`. Two verbs clear an optional key:

| python | intent |
|---|---|
| `h.pop("clean", None)` (`pool clean on`) | remove the `clean` flag → back to default-true |
| `h.pop("description", None)` (`pool desc <name>`) | clear the description |

Without delete, the port sets the default-equivalent value instead
(`clean = true`, `description = ""`). Behavior is identical — every reader uses
`json_object_get_bool(h, "clean", true)` / `_get_str(h, "description", "")` — but
the serialized `pool.json` carries a redundant `"clean": true` / `"description": ""`
where Python's omits the key.

## Ask

Add `json_object_delete(obj, key) -> bool` (returns whether the key existed) to
`stdlib/alloc/json_object`, routed in `codegen_c2.hexa` like the other
`json_object_*` builtins. Optionally `json_object_has(obj, key) -> bool` and
`json_object_keys(obj) -> [string]` while in there — all three are standard
JSON-object surface that's currently missing.

## Workaround in place (pool side)

`bin/pool.hexa` sets the default value (`clean=true` / `description=""`) — correct
behavior, redundant serialization. Switch to `json_object_delete` once it lands.

## Resolution (2026-05-23)

All three surface fns now live in `stdlib/alloc/json_object.hexa` — **pure-hexa,
no regen, no codegen_c2 dispatch change**:

- `json_object_keys(obj) -> [string]` — already present (predates this gap).
- `json_object_has(obj, key) -> bool` — added.
- `json_object_delete(obj, key) -> obj` — added; returns the SAME map reference
  (mutated in place), mirroring `json_object_set`. No-op when the key is absent
  or `obj` is not a map.

The JSON object is map-backed (`runtime.c hexa_json_parse` returns `TAG_MAP`), so
`json_object_delete` delegates to the existing `map_remove` builtin
(`codegen.hexa` → `hexa_map_remove`), which already returns the map unchanged when
the key is missing — no rebuild needed and **no transpiler regen** (the new fns are
picked up via the module loader). Note: the ask spelled the return as `-> bool`;
landed as `-> obj` to match the in-place idiom of `json_object_set` — use
`json_object_has` before delete if you need the existed/not-existed signal.

Verified by parse-gate + a built test: parse `{"a":1,"b":2,"clean":true}`,
`json_object_keys` lists `a,b,clean`, `json_object_delete(obj,"clean")` →
keys become `a,b`, `_get_bool` falls back to default, and deleting a
non-existent key is a no-op (no crash).
