// 本地差分对拍：本项目 CLI（js 后端）对 tools/ref/pronouncing_ref.mjs（上游忠实移植）。
//
// 用法（仓库根目录）：
//   node tools/diff_test.mjs              # 跑对拍，写 DIFF-REPORT.md
//   node tools/diff_test.mjs --no-report  # 只跑，结论打到 stdout
//
// 没有 Python 的机器用本脚本；CI 用 tools/diff_test.py 对真正的 Python pronouncing。
// 两侧输出字段完全对齐，逐字段精确比较（无浮点，全部要求相等）。
//
// 规范化口径（README「与上游的刻意差异」①）：上游 phones 带前导空格，ref 与 CLI
// 都在 phones / rhyming_parts 字段输出 trim + 折叠空格后的干净串，故可直接相等比较。
// rhymes 语料统一用小写词，避开上游大小写敏感的自身排除 footgun（差异②）。

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const MAIN_JS = path.join(ROOT, '_build', 'js', 'release', 'build', 'cmd', 'main', 'main.js');
const REF = path.join(__dirname, 'ref', 'pronouncing_ref.mjs');
const DATA = path.join(ROOT, 'data', 'upstream', 'cmudict-0.7b');
const NO_REPORT = process.argv.includes('--no-report');

const corpus = JSON.parse(readFileSync(path.join(__dirname, 'corpus.json'), 'utf-8'));

// 系统抽样：每 997 个条目取一个词（质数步长避免与词典周期对齐），保证覆盖面。
function sampleWords() {
  const text = readFileSync(DATA, 'latin1');
  const out = [];
  let i = 0;
  for (let line of text.split('\n')) {
    line = line.trim();
    if (!line || line.startsWith(';')) continue;
    if (i % 997 === 0) {
      out.push(line.slice(0, line.indexOf(' ')).split('(', 1)[0].toLowerCase());
    }
    i++;
  }
  return out;
}

const words = [...new Set([...corpus.words, ...sampleWords()])];
const queries = [];
for (const w of words) {
  for (const op of ['phones', 'rhymes', 'syllables', 'stress', 'info']) {
    queries.push({ op, arg: w });
  }
}
for (const p of corpus.search_patterns) queries.push({ op: 'search', arg: p });
for (const p of corpus.stress_patterns) queries.push({ op: 'stresses', arg: p });

function ensureBuild() {
  if (existsSync(MAIN_JS)) return;
  console.error('未找到 js 构建产物，先执行 moon build --target js --release …');
  const proc = spawnSync('moon', ['build', '--target', 'js', '--release'], {
    cwd: ROOT, shell: true, encoding: 'utf-8',
  });
  if (proc.status !== 0 || !existsSync(MAIN_JS)) {
    throw new Error('构建失败：' + (proc.stderr || proc.stdout));
  }
}

function runCli() {
  const byOp = new Map();
  queries.forEach((q, idx) => {
    if (!byOp.has(q.op)) byOp.set(q.op, []);
    byOp.get(q.op).push(idx);
  });
  const results = new Array(queries.length);
  for (const [op, idxs] of byOp) {
    for (let s = 0; s < idxs.length; s += 200) {
      const chunk = idxs.slice(s, s + 200);
      const args = [MAIN_JS, '--batch', '--json', op, '--', ...chunk.map((i) => queries[i].arg)];
      const proc = spawnSync(process.execPath, args, { encoding: 'utf-8', maxBuffer: 1 << 28 });
      if (proc.status !== 0) {
        throw new Error(`CLI 失败 op=${op} (exit ${proc.status}):\n${(proc.stderr || '').slice(-2000)}`);
      }
      const lines = proc.stdout.split('\n').filter((l) => l.trim());
      if (lines.length !== chunk.length) {
        throw new Error(`输出行数不符 op=${op}：期望 ${chunk.length}，实得 ${lines.length}`);
      }
      chunk.forEach((i, k) => { results[i] = JSON.parse(lines[k]); });
    }
  }
  return results;
}

function runRef() {
  const stdin = queries.map((q) => JSON.stringify(q)).join('\n') + '\n';
  const proc = spawnSync(process.execPath, [REF], { input: stdin, encoding: 'utf-8', maxBuffer: 1 << 28 });
  if (proc.status !== 0) throw new Error('参考实现失败：\n' + (proc.stderr || '').slice(-3000));
  const lines = proc.stdout.split('\n').filter((l) => l.trim());
  if (lines.length !== queries.length) {
    throw new Error(`参考实现输出行数不符：期望 ${queries.length}，实得 ${lines.length}`);
  }
  return lines.map((l) => JSON.parse(l));
}

const FIELDS = {
  phones: ['phones'], rhymes: ['rhymes'], syllables: ['syllables'], stress: ['stresses'],
  search: ['words'], stresses: ['words'],
  info: ['phones', 'stresses', 'syllables', 'rhyming_parts'],
};

function compare(q, ours, theirs) {
  const ms = [];
  for (const f of FIELDS[q.op]) {
    const a = JSON.stringify(ours[f]);
    const b = JSON.stringify(theirs[f]);
    if (a !== b) ms.push({ op: q.op, arg: q.arg, field: f, ours: ours[f], theirs: theirs[f] });
  }
  return ms;
}

function esc(v) {
  const s = JSON.stringify(v);
  return '`' + s.replace(/\\/g, '\\\\').replace(/\|/g, '\\|').slice(0, 120) + '`';
}

ensureBuild();
console.log(`词数: ${words.length}（精选 ${corpus.words.length} + 系统抽样，去重后）`);
console.log(`查询总数: ${queries.length}`);
const ours = runCli();
const theirs = runRef();
const mismatches = [];
queries.forEach((q, i) => mismatches.push(...compare(q, ours[i], theirs[i])));
const badQueries = new Set(mismatches.map((m) => JSON.stringify([m.op, m.arg])));
console.log(`\n完全一致查询: ${queries.length - badQueries.size}/${queries.length}`);
console.log(`字段级偏差: ${mismatches.length}`);
for (const m of mismatches.slice(0, 20)) {
  console.log(`  [${m.op}] ${JSON.stringify(m.arg)} .${m.field}`);
  console.log(`    ours  : ${JSON.stringify(m.ours).slice(0, 160)}`);
  console.log(`    theirs: ${JSON.stringify(m.theirs).slice(0, 160)}`);
}

if (!NO_REPORT) {
  const L = [];
  L.push('# DIFF-REPORT：pronouncing-MoonBit 对上游 pronouncing 差分对拍\n');
  L.push('生成方式：node tools/diff_test.mjs（本地，对忠实 JS 移植）；CI 用 python tools/diff_test.py 对真正的 Python pronouncing 包。\n');
  L.push('## 一、基准选择\n');
  L.push('对拍基准是 aparrish/pronouncingpy v0.3.0（MIT），即 CMUdict 之上那层薄算法的官方出处。');
  L.push('本地无 Python 时用 tools/ref/pronouncing_ref.mjs（逐行对照上游 __init__.py 的忠实移植）；');
  L.push('CI 安装真正的 pronouncing + cmudict 包做权威对拍。两者算法同源。\n');
  L.push('## 二、用例构成\n');
  L.push(`- 词数：${words.length}（精选语料 ${corpus.words.length} + 每 997 条目系统抽样，去重）`);
  L.push('- 每词跑 phones / rhymes / syllables / stress / info 五种查询');
  L.push(`- search 正则 ${corpus.search_patterns.length} 条、search_stresses 正则 ${corpus.stress_patterns.length} 条`);
  L.push(`- 查询总数：${queries.length}\n`);
  L.push('## 三、比较口径\n');
  L.push('| 字段 | 口径 |');
  L.push('| --- | --- |');
  L.push('| phones / rhymes / syllables / stresses / words / rhyming_parts | 精确相等（含顺序与重复） |');
  L.push('| phones / rhyming_parts | 两侧均 trim + 折叠空格后比较（差异①） |');
  L.push('| info 的 ipa 字段 | 不参与对拍（上游无 IPA，属增值功能，由 arpabet_test.mbt 单测覆盖） |\n');
  L.push('search / search_stresses 按条目返回（同一词多个发音命中会重复出现），两侧都保留重复与字典序，精确相等。\n');
  L.push('## 四、结果\n');
  L.push(`- 查询总数：${queries.length}`);
  L.push(`- 完全一致：${queries.length - badQueries.size}`);
  L.push(`- 字段级偏差：${mismatches.length}`);
  L.push(`- 存在偏差的查询：${badQueries.size}\n`);
  if (mismatches.length) {
    L.push('### 偏差明细（前 60 条）\n');
    L.push('| op | arg | 字段 | 本库 | 上游 |');
    L.push('| --- | --- | --- | --- | --- |');
    for (const m of mismatches.slice(0, 60)) {
      L.push(`| ${m.op} | ${esc(m.arg)} | ${m.field} | ${esc(m.ours)} | ${esc(m.theirs)} |`);
    }
    L.push('');
  } else {
    L.push('未预期不一致为 0——本库与上游在全部查询上逐字段一致（规范化口径内）。\n');
  }
  L.push('## 五、与上游的刻意差异\n');
  L.push('1. phones 单空格规范化：上游 parse_cmu 用 split 单空格 maxsplit=1，CMUdict 词与音素间是两空格，');
  L.push('   故上游 phones 带前导空格；本库去前导空格并折叠为单空格，语义等价（stresses/syllable_count/');
  L.push('   rhyming_part/search 都用 split 语义，不受影响），且匹配上游 doctest 的干净输出。');
  L.push('2. rhymes 自身排除按小写比较：上游用原始大小写比较，传入大写词时不会排除自身；');
  L.push('   本库统一小写比较，修正该 footgun。对拍语料统一小写，二者一致。\n');
  L.push('## 六、复现\n');
  L.push('```bash');
  L.push('moon build --target js --release   # 构建 CLI');
  L.push('node tools/diff_test.mjs           # 本地对拍并生成本报告');
  L.push('# CI：pip install pronouncing cmudict && python tools/diff_test.py');
  L.push('```\n');
  writeFileSync(path.join(ROOT, 'DIFF-REPORT.md'), L.join('\n'));
  console.log('\n报告已写入 DIFF-REPORT.md');
}

process.exit(mismatches.length ? 1 : 0);