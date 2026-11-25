// pronouncing 上游算法的忠实 JS 移植，供本地差分对拍（tools/diff_test.mjs）。
//
// 逐行对照 https://github.com/aparrish/pronouncingpy/blob/master/pronouncing/__init__.py
// （Allison Parrish, MIT, v0.3.0）。CI 侧 tools/diff_test.py 改用真正的 Python
// `pronouncing` 包做权威对拍；本文件让没有 Python 的机器也能本地复现。
//
// 输入：stdin 每行一个查询 {"op": "...", "arg": "..."}。
// 输出：stdout 每行一个 JSON，字段与 cmd/main 的 result_json 完全对齐。
//
// 规范化说明（README「与上游的刻意差异」①②）：SourceForge 原始 cmudict-0.7b
// 词与音素之间是**两个空格**，上游 parse_cmu 用 `line.split(" ", 1)` 会留下一个
// 前导空格；但上游 doctest 给出的 phones 是干净单空格串。本移植在 parseCmu 即把
// phones 规范化为 trim + 折叠空格（与本项目嵌入数据一致），从而 rhyming_part 的
// fallback 分支也返回干净串、押韵键一致。rhymes 自身排除按小写比较（差异②，修正
// 上游大小写敏感 footgun）。这两处刻意差异同样施加于参考侧，使对拍隔离验证「算法
// 本身」的正确性；差异本身在 README 与 DIFF-REPORT 中声明。

import { readFileSync } from 'node:fs';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_PATH = path.join(__dirname, '..', '..', 'data', 'upstream', 'cmudict-0.7b');

const norm = (s) => s.trim().replace(/\s+/g, ' ');

// parse_cmu：跳过 ';' 注释；按第一个空格切分（maxsplit=1）；词去 (n) 变体后缀并小写。
function parseCmu(text) {
  const out = [];
  for (let line of text.split('\n')) {
    line = line.trim();
    if (line === '' || line.startsWith(';')) continue;
    const idx = line.indexOf(' ');
    const word = line.slice(0, idx);
    const phones = line.slice(idx + 1);
    out.push([word.split('(', 1)[0].toLowerCase(), norm(phones)]);
  }
  return out;
}

const pronunciations = parseCmu(readFileSync(DATA_PATH, 'latin1'));
const lookup = new Map();
const rhymeLookup = new Map();
for (const [word, phones] of pronunciations) {
  if (!lookup.has(word)) lookup.set(word, []);
  lookup.get(word).push(phones);
}

function stresses(s) {
  return s.replace(/[^012]/g, '');
}

function syllableCount(phones) {
  return stresses(phones).length;
}

function rhymingPart(phones) {
  const list = phones.split(/\s+/).filter(Boolean);
  for (let i = list.length - 1; i >= 1; i--) {
    const last = list[i][list[i].length - 1];
    if (last === '1' || last === '2') return list.slice(i).join(' ');
  }
  return phones;
}

for (const [word, phones] of pronunciations) {
  const rp = rhymingPart(phones);
  if (rp != null) {
    if (!rhymeLookup.has(rp)) rhymeLookup.set(rp, []);
    rhymeLookup.get(rp).push(word);
  }
}

function phonesForWord(word) {
  return lookup.get(word.toLowerCase()) || [];
}

function rhymes(word) {
  const phones = phonesForWord(word);
  if (!phones.length) return [];
  const combined = [];
  for (const p of phones) {
    for (const w of rhymeLookup.get(rhymingPart(p)) || []) {
      if (w !== word.toLowerCase()) combined.push(w); // 差异②：小写自身排除
    }
  }
  // JS 默认 sort 是按 UTF-16 码元的纯字典序（非 shortlex），与 Python sorted 一致。
  return [...new Set(combined)].sort();
}

function search(pattern) {
  const re = new RegExp('\\b' + pattern + '\\b');
  return pronunciations.filter(([, p]) => re.test(p)).map(([w]) => w);
}

function searchStresses(pattern) {
  const re = new RegExp(pattern);
  return pronunciations.filter(([, p]) => re.test(stresses(p))).map(([w]) => w);
}

function result(op, arg) {
  switch (op) {
    case 'phones':
      return { op, word: arg, phones: phonesForWord(arg).map(norm) };
    case 'rhymes':
      return { op, word: arg, rhymes: rhymes(arg) };
    case 'syllables':
      return { op, word: arg, syllables: phonesForWord(arg).map(syllableCount) };
    case 'stress':
      return { op, word: arg, stresses: phonesForWord(arg).map(stresses) };
    case 'search':
      return { op, pattern: arg, words: search(arg) };
    case 'stresses':
      return { op, pattern: arg, words: searchStresses(arg) };
    case 'info': {
      const ps = phonesForWord(arg);
      return {
        op,
        word: arg,
        phones: ps.map(norm),
        stresses: ps.map(stresses),
        syllables: ps.map(syllableCount),
        rhyming_parts: ps.map((p) => norm(rhymingPart(p))),
      };
    }
    default:
      throw new Error('unknown op: ' + op);
  }
}

const rl = createInterface({ input: process.stdin });
rl.on('line', (line) => {
  line = line.trim();
  if (!line) return;
  const { op, arg } = JSON.parse(line);
  process.stdout.write(JSON.stringify(result(op, arg)) + '\n');
});