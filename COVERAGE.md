# Coverage Report

Generated: 2026-11-25
Toolchain: `.moonbit-version` (moonc v0.10.22+124d61d05)
Command: `moon coverage analyze`
Target: wasm (default)

## Current snapshot

The 40 MoonBit tests pass on wasm, wasm-gc and js. The wasm instrumentation report
contains **88 uncovered lines in 3 files**. This is an uncovered-line count, not a
branch-coverage percentage or proof that the algorithm is complete.

| File | Uncovered lines |
| --- | ---: |
| arpabet.mbt | 0 |
| cmudict.mbt | 2 |
| cmd/main/main.mbt | 62 |
| demo/web/pronouncing_web.mbt | 24 |
| **Total** | **88** |

## What is and is not verified

`arpabet.mbt` has **no uncovered lines**: all 15 vowels and all 24 consonants are
individually asserted through `phone_to_ipa`, including the stress-aware AH/ER
branches, plus `arpabet_to_ipa`, `phone_kind`, `is_vowel`, `strip_stress`,
`stress_of` and `phone_edit_distance`.

The 2 uncovered lines in `cmudict.mbt` are **defensive guards unreachable with the
embedded data**: the empty-phones skip in `build_data` (the generator emits no
empty-phones entry) and the `None` arm of `rhyme_lookup.get` in `rhymes` (every
entry's rhyming part is indexed during the same build, so the lookup always hits).
They are kept for robustness, not proven reachable.

The 62 lines in `cmd/main/main.mbt` and 24 in `demo/web/pronouncing_web.mbt` are the
CLI and the browser export. They run in **separate processes** (`moon run` / node)
against the compiled artifacts, so their execution is not merged into this wasm
line-coverage snapshot. They are exercised by the differential harness
(`tools/diff_test.mjs`, 5967 queries) and the demo smoke test
(`node --test tools/test_demo.mjs`); the uncovered-line count here does not mean
those paths lack integration tests.

## Reproduce

```bash
moon coverage analyze > uncovered.log
bash demo/build.sh
node tools/diff_test.mjs --no-report
node --test tools/test_demo.mjs
# CI 权威对拍：pip install pronouncing cmudict && python tools/diff_test.py --no-report
```

Coverage line numbers and totals change when source or toolchain versions change.
Regenerate the report before relying on this snapshot for a later revision.