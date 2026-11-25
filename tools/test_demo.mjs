// demo web 导出的冒烟测试（node --test tools/test_demo.mjs）。
// 先 bash demo/build.sh 生成 demo/pronouncing.js。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pronouncingReport } from '../demo/pronouncing.js';

test('info permit matches official doctest', () => {
  const r = JSON.parse(pronouncingReport('info', 'permit'));
  assert.deepEqual(r.phones, ['P ER0 M IH1 T', 'P ER1 M IH2 T']);
  assert.deepEqual(r.stresses, ['01', '12']);
  assert.deepEqual(r.syllables, [2, 2]);
  assert.deepEqual(r.ipa, ['p ɚ m ɪ t', 'p ɝ m ɪ t']);
});

test('rhymes conditioner is sorted and unique', () => {
  const r = JSON.parse(pronouncingReport('rhymes', 'conditioner'));
  assert.deepEqual(r.rhymes, ['commissioner', 'parishioner', 'petitioner', 'practitioner']);
});

test('search interpolate membership', () => {
  const r = JSON.parse(pronouncingReport('search', 'ER1 P AH0'));
  assert.ok(r.words.includes('interpolate'));
});

test('invalid regex returns structured error, not a crash', () => {
  const r = JSON.parse(pronouncingReport('search', '['));
  assert.ok(r.error);
});

test('word not in dictionary yields empty phones', () => {
  const r = JSON.parse(pronouncingReport('phones', 'zzzznotaword'));
  assert.deepEqual(r.phones, []);
});