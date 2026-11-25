# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project: a port of the CMU
Pronouncing Dictionary + `aparrish/pronouncingpy`, with ARPABET↔IPA value-add.

## Project Structure

- The root package `PaperY0/pronouncing` is the pure-computation library
  (`cmudict.mbt`, `arpabet.mbt`) plus the embedded dictionary `cmudict_data.mbt`
  (generated, DO NOT EDIT). `cmd/main` is the CLI; `demo/web` is the browser
  ES-module export; `tools/` holds the generator and differential harnesses.
- Each directory has a `moon.pkg` listing dependencies. Blackbox tests end in
  `_test.mbt`, whitebox tests in `_wbtest.mbt`.

## Coding convention

- Code is organized in block style; each block is separated by `///|`. Block
  order is irrelevant.
- Keep deprecated blocks in `deprecated.mbt` per directory.
- Public enum variants that callers must construct use `pub(all) enum`.
- Sorting strings: MoonBit's `Compare for String` is shortlex (length first).
  For Python-compatible lexicographic order use `String::lexical_compare`
  (see the `LexWord` wrapper in `cmudict.mbt`).

## Tooling

- `moon fmt` formats; `moon info` regenerates `.mbti` interfaces. Run
  `moon info && moon fmt` as the last step and check `.mbti` diffs.
- `moon test` runs tests; the library is verified on wasm / wasm-gc / js.
- Regenerate the dictionary: `node tools/gen_cmudict.mjs` (reads
  `data/upstream/cmudict-0.7b`, writes `cmudict_data.mbt`), then `moon fmt`.
- Differential check: `node tools/diff_test.mjs` (local, faithful JS port) or
  `python tools/diff_test.py` (CI, real `pronouncing` package). Both rewrite
  `DIFF-REPORT.md`.
- Build the demo: `bash demo/build.sh` (generates `demo/pronouncing.js`).