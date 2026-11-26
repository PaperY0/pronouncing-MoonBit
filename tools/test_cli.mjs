// CLI 集成测试：对 js 后端构建产物逐子命令验证输出契约与错误退出码。
//
// 用法（仓库根目录）：
//   moon build --target js --release   # 若产物缺失，脚本会自动触发
//   node --test tools/test_cli.mjs
//
// 与差分对拍（diff_test.*）互补：对拍验证"和上游一致"，这里验证 CLI 自身的
// 接口契约——JSON 字段、人类可读格式、--help/--batch、参数错误必须非零退出。

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const MAIN_JS = path.join(ROOT, '_build', 'js', 'release', 'build', 'cmd', 'main', 'main.js');

if (!existsSync(MAIN_JS)) {
  const proc = spawnSync('moon', ['build', '--target', 'js', '--release'], {
    cwd: ROOT, shell: true, encoding: 'utf-8',
  });
  if (proc.status !== 0 || !existsSync(MAIN_JS)) {
    console.error('构建 js 产物失败：', proc.stderr || proc.stdout);
    process.exit(1);
  }
}

function cli(...args) {
  return spawnSync(process.execPath, [MAIN_JS, ...args], {
    cwd: ROOT, encoding: 'utf-8',
  });
}

function cliJson(...args) {
  const r = cli(...args, '--json');
  assert.equal(r.status, 0, `exit 0 expected, stderr: ${r.stderr}`);
  return JSON.parse(r.stdout);
}

test('phones: exact JSON contract', () => {
  assert.deepEqual(cliJson('phones', 'permit'), {
    op: 'phones', word: 'permit',
    phones: ['P ER0 M IH1 T', 'P ER1 M IH2 T'],
  });
});

test('phones: case-insensitive lookup, word echoed verbatim', () => {
  const r = cliJson('phones', 'PERMIT');
  assert.equal(r.word, 'PERMIT');
  assert.deepEqual(r.phones, ['P ER0 M IH1 T', 'P ER1 M IH2 T']);
});

test('phones: latin-1 headword déjà (regression for 0.1.1 fix)', () => {
  assert.deepEqual(cliJson('phones', 'déjà').phones, ['D EY2 JH AA1']);
});

test('rhymes: sorted unique, self excluded', () => {
  assert.deepEqual(cliJson('rhymes', 'conditioner').rhymes,
    ['commissioner', 'parishioner', 'petitioner', 'practitioner']);
});

test('syllables: one count per pronunciation', () => {
  const r = cliJson('syllables', 'literally');
  assert.ok(r.syllables.length >= 1);
  assert.equal(r.syllables[0], 4); // 上游官方 doctest
});

test('stress: patterns per pronunciation', () => {
  assert.deepEqual(cliJson('stress', 'permit').stresses, ['01', '12']);
});

test('ipa: stress-aware transcription', () => {
  assert.deepEqual(cliJson('ipa', 'permit').ipa, ['p ɚ m ɪ t', 'p ɝ m ɪ t']);
});

test('info: all five fields aligned with phones', () => {
  const r = cliJson('info', 'permit');
  assert.deepEqual(r.phones, ['P ER0 M IH1 T', 'P ER1 M IH2 T']);
  assert.deepEqual(r.stresses, ['01', '12']);
  assert.deepEqual(r.syllables, [2, 2]);
  assert.deepEqual(r.rhyming_parts, ['IH1 T', 'IH2 T']);
  assert.deepEqual(r.ipa, ['p ɚ m ɪ t', 'p ɝ m ɪ t']);
});

test('search: official doctest pattern', () => {
  const r = cliJson('search', 'ER1 P AH0');
  assert.ok(r.words.includes('interpolate'));
});

test('stresses: anchored official doctest', () => {
  assert.deepEqual(cliJson('stresses', '020120').words, ['gubernatorial']);
});

test('human output: phones prints one per line', () => {
  const r = cli('phones', 'permit');
  assert.equal(r.status, 0);
  assert.equal(r.stdout, 'P ER0 M IH1 T\nP ER1 M IH2 T\n');
});

test('human output: unknown word is reported, exit 0', () => {
  const r = cli('phones', 'zzznotaword');
  assert.equal(r.status, 0);
  assert.equal(r.stdout.trim(), '(not in dictionary)');
});

test('--help lists all eight commands, exit 0', () => {
  const r = cli('--help');
  assert.equal(r.status, 0);
  for (const cmd of ['phones', 'rhymes', 'syllables', 'stress', 'search', 'stresses', 'ipa', 'info']) {
    assert.ok(r.stdout.includes(cmd), `help must mention ${cmd}`);
  }
  assert.ok(r.stdout.includes('usage:'));
});

test('--batch emits one JSON object per argument (JSON Lines)', () => {
  const r = cli('--batch', '--json', 'phones', 'cat', 'dog', 'bird');
  assert.equal(r.status, 0);
  const lines = r.stdout.trim().split('\n');
  assert.equal(lines.length, 3);
  const objs = lines.map((l) => JSON.parse(l));
  assert.deepEqual(objs.map((o) => o.word), ['cat', 'dog', 'bird']);
  for (const o of objs) {
    assert.equal(o.op, 'phones');
    assert.ok(o.phones.length >= 1);
  }
});

test('invalid regex exits non-zero with error on stderr', () => {
  const r = cli('search', '[');
  assert.notEqual(r.status, 0);
  assert.ok(r.stderr.includes('error:'));
});

test('unknown command / option / missing arg all exit non-zero', () => {
  for (const args of [['bogus', 'x'], ['phones', 'permit', '--bogus'], ['phones'], ['--batch', 'phones']]) {
    const r = cli(...args);
    assert.notEqual(r.status, 0, `args ${JSON.stringify(args)} must fail`);
    assert.ok(r.stderr.includes('error:'));
  }
});