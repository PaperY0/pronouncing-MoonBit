import { pronouncingReport } from './pronouncing.js';

self.onmessage = ({ data: { id, op, arg } }) => {
  try {
    if (Array.from(arg).length > 256) {
      throw new Error('演示页最多处理 256 个 Unicode 字符，请缩短输入。');
    }
    self.postMessage({ id, result: JSON.parse(pronouncingReport(op, arg)) });
  } catch (error) {
    self.postMessage({ id, error: error.message });
  }
};