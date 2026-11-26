# DIFF-REPORT：pronouncing-MoonBit 对上游 pronouncing 差分对拍

生成方式：node tools/diff_test.mjs（本地，对忠实 JS 移植）；CI 用 python tools/diff_test.py 对真正的 Python pronouncing 包。

## 一、基准选择

对拍基准是 aparrish/pronouncingpy v0.3.0（BSD-3-Clause），即 CMUdict 之上那层薄算法的官方出处。
本地无 Python 时用 tools/ref/pronouncing_ref.mjs（逐行对照上游 __init__.py 的忠实移植）；
CI 安装真正的 pronouncing + cmudict 包做权威对拍。两者算法同源。

## 二、用例构成

- 词数：1184（精选语料 1082 + 每 997 条目系统抽样，去重）
- 每词跑 phones / rhymes / syllables / stress / info 五种查询
- search 正则 25 条、search_stresses 正则 22 条
- 查询总数：5967

## 三、比较口径

| 字段 | 口径 |
| --- | --- |
| phones / rhymes / syllables / stresses / words / rhyming_parts | 精确相等（含顺序与重复） |
| phones / rhyming_parts | 两侧均 trim + 折叠空格后比较（差异①） |
| info 的 ipa 字段 | 不参与对拍（上游无 IPA，属增值功能，由 arpabet_test.mbt 单测覆盖） |

search / search_stresses 按条目返回（同一词多个发音命中会重复出现），两侧都保留重复与字典序，精确相等。

## 四、结果

- 查询总数：5967
- 完全一致：5967
- 字段级偏差：0
- 存在偏差的查询：0

未预期不一致为 0——本库与上游在全部查询上逐字段一致（规范化口径内）。

## 五、与上游的刻意差异

1. phones 单空格规范化：上游 parse_cmu 用 split 单空格 maxsplit=1，CMUdict 词与音素间是两空格，
   故上游 phones 带前导空格；本库去前导空格并折叠为单空格，语义等价（stresses/syllable_count/
   rhyming_part/search 都用 split 语义，不受影响），且匹配上游 doctest 的干净输出。
2. rhymes 自身排除按小写比较：上游用原始大小写比较，传入大写词时不会排除自身；
   本库统一小写比较，修正该 footgun。对拍语料统一小写，二者一致。

## 六、复现

```bash
moon build --target js --release   # 构建 CLI
node tools/diff_test.mjs           # 本地对拍并生成本报告
# CI：pip install pronouncing cmudict && python tools/diff_test.py
```
