// 演示页逻辑：读输入 → 在 Worker 内查询 → 渲染最新请求的结果。
// 所有计算都在浏览器内完成（demo/pronouncing.js 是 MoonBit 编到 js 后端的产物），
// 没有任何 fetch / XHR。

const worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });
let requestId = 0;
let pending;
let workerFailed = false;

const $ = (id) => document.getElementById(id);
const arg = $('arg');
const op = $('op');
const MAX_SHOW = 500;

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text != null) e.textContent = text;
  return e;
}

function render(r) {
  $('result').hidden = false;
  const out = $('out');
  out.replaceChildren();
  if (r.error) {
    out.appendChild(el('p', 'error', '错误：' + r.error));
    return;
  }
  if (r.op === 'info') {
    if (!r.phones.length) {
      out.appendChild(el('p', 'hint', '（不在词典中）'));
      return;
    }
    r.phones.forEach((p, i) => {
      const d = el('div', 'pron');
      d.appendChild(el('div', 'phones', p));
      d.appendChild(el('div', 'ipa', '/' + r.ipa[i] + '/'));
      const meta = el('div', 'meta');
      meta.append('重音 ', el('code', null, r.stresses[i]),
        ' · 音节 ' + r.syllables[i] + ' · 押韵部 ', el('code', null, r.rhyming_parts[i]));
      d.appendChild(meta);
      out.appendChild(d);
    });
    return;
  }

  let items, label;
  if (r.op === 'rhymes') { items = r.rhymes; label = '押韵词'; }
  else if (r.op === 'search' || r.op === 'stresses') { items = r.words; label = '匹配词'; }
  else if (r.op === 'phones') { items = r.phones; label = '发音'; }
  else if (r.op === 'ipa') { items = r.ipa; label = 'IPA'; }
  else if (r.op === 'stress') { items = r.stresses; label = '重音'; }
  else if (r.op === 'syllables') { items = r.syllables.map(String); label = '音节数'; }
  else { items = []; label = ''; }

  const shown = items.slice(0, MAX_SHOW);
  let count = label + '：' + items.length + ' 个';
  if (items.length > MAX_SHOW) count += '（仅显示前 ' + MAX_SHOW + ' 个）';
  out.appendChild(el('p', 'count', count));
  const ul = el('ul', 'words');
  if (!shown.length) ul.appendChild(el('li', 'empty', '（无结果）'));
  else for (const it of shown) ul.appendChild(el('li', null, it));
  out.appendChild(ul);
}

function update() {
  const id = ++requestId;
  clearTimeout(pending);
  $('result').hidden = true;
  $('status').textContent = workerFailed ? '加载失败，请刷新页面重试。' : '正在查询…';
  if (workerFailed) return;
  pending = setTimeout(() => worker.postMessage({ id, op: op.value, arg: arg.value }), 150);
}

worker.onmessage = ({ data }) => {
  if (data.id !== requestId) return;
  $('status').textContent = data.error ?? '';
  if (!data.error) render(data.result);
};
worker.onerror = () => {
  workerFailed = true;
  clearTimeout(pending);
  $('result').hidden = true;
  $('status').textContent = '加载失败，请刷新页面重试。';
};

arg.addEventListener('input', update);
op.addEventListener('change', update);
update();