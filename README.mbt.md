# PaperY0/pronouncing

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.2-6c4ce0)](https://mooncakes.io/docs/PaperY0/pronouncing)
[![Backend](https://img.shields.io/badge/Backend-wasm_%7C_wasm--gc_%7C_js-2ea44f)](https://github.com/PaperY0/pronouncing-MoonBit/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)
[![Differential](https://img.shields.io/badge/Differential-5%2C967_queries_%C2%B7_0_deviations-brightgreen)](DIFF-REPORT.md)
[![CI](https://github.com/PaperY0/pronouncing-MoonBit/actions/workflows/ci.yml/badge.svg)](https://github.com/PaperY0/pronouncing-MoonBit/actions/workflows/ci.yml)

[中文](#papery0pronouncing) | [English](#papery0pronouncing-en)

> CMU 发音词典（[CMUdict](http://www.speech.cs.cmu.edu/cgi-bin/cmudict)）+ Allison Parrish
> [pronouncing](https://github.com/aparrish/pronouncingpy) 的 MoonBit 移植，外加 **ARPABET↔IPA** 增值。
> 输入一个英文词，输出 **ARPABET 发音 + 重音模式 + 音节数 + 押韵部 + 押韵词 + IPA 转写**；也可用正则搜索整个词典的发音/重音。

## 为什么是它（生态零重合）

MoonBit 生态里**没有发音词典 / 音素分析**这一整簇能力。用官方 `moon search` 逐词检索
`cmudict` / `arpabet` / `pronouncing` / `phoneme` / `g2p` / `pronunciation` / `rhyme` /
`ipa` / `syllable` 等关键词，均返回 No modules found；对 mooncakes.io 约 3883 个模块、
150 组关键词的全量扫描确认这里是空白。

唯一名字相邻的模块是 `moonbit-phonetic`，但它只做 **Soundex / Metaphone 姓名哈希**——把
发音相似的姓氏编码成同一个键（用于模糊匹配人名），与「查一个词的标准发音、数音节、找押韵、
转 IPA」是**完全不同的领域**：前者是有损的相似度哈希，后者是无损的音素词典查询。本模块与它
零功能重合，与生态里任何其它模块也不重合（TTS / ASR / 分词 / 翻译等方向 likewise 无相邻实现）。

本模块把 Python `pronouncing` 那层薄而经典的算法（词典查询、重音提取、押韵部、正则搜索）
完整搬到 MoonBit，并补上上游没有的 **ARPABET→IPA** 转写、音素分类（元音/塞音/擦音…）与
音素编辑距离。纯计算、无 IO，wasm / wasm-gc / js 三后端均可用。

## 能力范围

- **词典**：CMUdict 0.7b，**133,852 条目**（含同一词的多个发音变体），39 个基础音素
  （15 元音 + 24 辅音）。数据以 `#|` 多行字符串分块嵌入源码，惰性建 Map，无需运行时读文件。
- **pronouncing 等价 API**：`phones_for_word` / `stresses` / `stresses_for_word` /
  `syllable_count` / `rhyming_part` / `rhymes` / `search` / `search_stresses`。
- **ARPABET 增值**：`ipa_for_word`（词直达 IPA）、`arpabet_to_ipa`（整串转写，重音感知：AH0→ə / AH1→ʌ，ER0→ɚ / ER1→ɝ）、
  `phone_to_ipa`（单音素）、`phone_kind`（Vowel/Stop/Affricate/Fricative/Aspirate/Liquid/Nasal/Semivowel）、
  `is_vowel` / `strip_stress` / `stress_of` / `phone_edit_distance`（忽略重音的 Levenshtein）。

## API 设计

```moonbit nocheck
// pronouncing 等价层
pub fn phones_for_word(String) -> Array[String]          // 一个词的全部发音（ARPABET）
pub fn stresses(String) -> String                        // 提取重音数字，如 "0100"
pub fn stresses_for_word(String) -> Array[String]
pub fn syllable_count(String) -> Int                     // 音节数 = 重音数字个数
pub fn rhyming_part(String) -> String                    // 末尾重读元音起的押韵部
pub fn rhymes(String) -> Array[String]                   // 押韵词（纯字典序、去重、排除自身）
pub fn search(String) -> Array[String] raise PronouncingError          // 发音正则（自动加 \b）
pub fn search_stresses(String) -> Array[String] raise PronouncingError // 重音正则（不加 \b）
pub fn entry_count() -> Int                              // 133852
pub fn word_count() -> Int

// ARPABET / IPA 增值层
pub fn ipa_for_word(String) -> Array[String]               // 词 → IPA（查发音并逐条转写）
pub fn arpabet_to_ipa(String) -> String                  // "P ER0 M IH1 T" -> "p ɚ m ɪ t"
pub fn phone_to_ipa(String) -> String?
pub fn phone_kind(String) -> PhoneKind?
pub fn is_vowel(String) -> Bool
pub fn strip_stress(String) -> String                    // "AH1" -> "AH"
pub fn stress_of(String) -> Int?
pub fn phone_edit_distance(String, String) -> Int        // 忽略重音的音素 Levenshtein
pub let arpabet_vowels : Array[String]                   // 15 个
pub let arpabet_consonants : Array[String]               // 24 个

pub(all) enum PhoneKind { Vowel; Stop; Affricate; Fricative; Aspirate; Liquid; Nasal; Semivowel }
pub suberror PronouncingError { InvalidRegex(String) }
```

## 三个使用场景

1. **库调用（服务端 / wasm）**：`@pronouncing.phones_for_word("permit")` →
   `["P ER0 M IH1 T", "P ER1 M IH2 T"]`；`@pronouncing.arpabet_to_ipa(...)` 转 IPA。
2. **CLI 工具**：`moon run cmd/main -- info permit` 打印发音/重音/音节/押韵部/IPA；
   `rhymes` / `search` / `stresses` / `ipa` 等子命令；`--json` 机器可读、`--batch` 输出 JSON Lines（供差分对拍）。
3. **浏览器词典页**：[`demo/`](demo/) 输入即查，全部计算在本地 Worker 完成，查询不发送数据。
   MoonBit 编 js 后端出 ES module，`pronouncingReport(op, arg)` 返回 JSON 字符串。详见 [`demo/README.md`](demo/README.md)。

```bash
moon run cmd/main -- info permit
moon run cmd/main -- rhymes conditioner --json
moon run cmd/main -- search "ER1 P AH0" --json
moon run cmd/main -- --batch --json syllables literally permit
```

## 安装与最小样例

已发布到 [mooncakes.io](https://mooncakes.io/docs/PaperY0/pronouncing)（`PaperY0/pronouncing`）。
在任意 MoonBit 项目中使用：

```bash
moon new hello_pronouncing && cd hello_pronouncing
moon add PaperY0/pronouncing
```

`cmd/main/moon.pkg` 加入依赖：

```text
import {
  "PaperY0/pronouncing" @pronouncing,
}
```

`cmd/main/main.mbt` 写入最小样例：

```moonbit nocheck
///|
fn main {
  // 查一个词的全部发音（ARPABET）
  let phones = @pronouncing.phones_for_word("permit")
  for p in phones {
    println(p)
  }
  // 转 IPA（重音感知）
  println(@pronouncing.arpabet_to_ipa(phones[0]))
  // 便捷 API：词直达 IPA（0.1.2 起）
  for ipa in @pronouncing.ipa_for_word("permit") {
    println(ipa)
  }
}
```

`moon run cmd/main` 输出（对已发布的 0.1.2 实测）：

```text
P ER0 M IH1 T
P ER1 M IH2 T
p ɚ m ɪ t
p ɚ m ɪ t
p ɝ m ɪ t
```

## 与上游的刻意差异（逐条说明）

1. **phones 单空格规范化。** SourceForge 原始 `cmudict-0.7b` 词与音素之间是**两个空格**，
   上游 `parse_cmu` 用 `line.split(" ", 1)` 会留下一个前导空格；本库在生成数据时即折叠为
   单空格、去前导空格。语义完全等价（`stresses` / `syllable_count` / `rhyming_part` / `search`
   都用 `split()` 语义，不受多余空格影响），且与上游 doctest 给出的干净输出一致。
   附带修正：上游 `rhyming_part` 在「重读元音落在第一个音素」时 fallback 返回原始串，
   规范化后押韵键不再因前导空格而错配（如 `ocean` / `arc` 的押韵词在上游会漏）。
2. **rhymes 自身排除按小写比较。** 上游 `if w != word` 用传入的原始大小写，传 `"Permit"`
   时不会排除词典里的小写 `permit`（自身出现在自己的押韵词里）；本库统一小写比较，修正该 footgun。
3. **MoonBit 字符串排序是 shortlex。** 核心库 `Compare for String` 先比长度再比内容，与
   Python `sorted()` 的纯字典序不同。本库用 `String::lexical_compare` 包装（`LexWord`）保证
   `rhymes` / `search` 输出纯字典序，与上游一致。
4. **正则 `\b` 手动校验。** MoonBit core Regex 无通用 `\b` 断言，`search` 用引擎找匹配后
   手动校验匹配两侧的词边界（`[A-Za-z0-9_]` 与非词字符之交），语义等价于上游 `\b...\b`。
   `search` / `search_stresses` 与上游一样**按条目返回**（同一词多个发音命中会重复出现），保留字典序。

## 测试策略

**48 个 MoonBit 测试全部通过**，三后端各 48/48；另有跨语言差分对拍：

1. **上游官方 doctest 向量**：`phones_for_word("permit")`、`syllable_count(literally[0])==4`、
   `stresses(obsequious[0])=="0100"`、`rhyming_part(purple[0])=="ER1 P AH0 L"`、
   `rhymes("conditioner")`、`search("ER1 P AH0")` 含 `interpolate`、
   `search_stresses("020120")==["gubernatorial"]`、`entry_count()==133852` 等逐条转写。
2. **ARPABET / IPA**：39 音素逐个转写、重音感知 AH/ER、音素分类、编辑距离（替换/插入/删除）。
3. **白盒 + 边界**：内部 helper（切分/词边界/排序去重）、空串、不在词典的词、非法正则 raise。

```bash
moon check   # 0 error，0 warning
moon test    # 48/48（默认 wasm）
moon test --target wasm-gc  # 48/48
moon test --target js       # 48/48
```

**差分对拍**：[`DIFF-REPORT.md`](DIFF-REPORT.md)——对上游 `pronouncing` 跑 **5967 个查询**
（1184 词 × 5 种查询 + 47 条正则），**逐字段完全一致，未预期不一致 0**。
本地用 `node tools/diff_test.mjs`（对忠实 JS 移植），CI 用 `python tools/diff_test.py`
（对真正的 Python `pronouncing` 包）。两处刻意差异同样施加于参考侧，以隔离验证算法本身。

## 非目标（明确不做）

文本到音素（G2P，词典外的词无法发音）、TTS / ASR、多语言词典、Grapheme 级 Unicode 处理。
本模块是**词典查询**：只覆盖 CMUdict 收录的词；未收录词返回空。

## 开发

工具链版本固定在 [`.moonbit-version`](.moonbit-version)：

```bash
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash -s -- "$(cat .moonbit-version)"
```

```bash
moon check / moon info / moon fmt / moon test
moon run cmd/main -- info permit
node tools/gen_cmudict.mjs        # 从 data/upstream/cmudict-0.7b 重新生成 cmudict_data.mbt（需 Node）
node tools/diff_test.mjs          # 本地差分对拍，重写 DIFF-REPORT.md
python tools/diff_test.py         # CI 权威对拍（pip install pronouncing cmudict）
bash demo/build.sh                # 构建 JS 并生成 demo/pronouncing.js
node --test tools/test_demo.mjs   # demo 导出冒烟测试
# 生成器产物需再跑一次 moon fmt（CI 的 fmt 门禁会校验）
```

> `tools/gen_cmudict.mjs` 需要 Node（无第三方依赖）。`tools/diff_test.py` 需要 Python 3 +
> `pronouncing` + `cmudict` 包；`tools/diff_test.mjs` 只需 Node。

## 数据与许可

- 词典数据来自 CMUdict 0.7b（`cmusphinx`，SourceForge trunk），**BSD-like 许可（无限制使用，需署名），
  (c) Carnegie Mellon University**，见 [`data/README.md`](data/README.md)。
- 算法来自 `aparrish/pronouncingpy`（**BSD-3-Clause**, (c) 2015 Allison Parrish，全文见 [LICENSE](LICENSE)）。
- 本项目以 MIT 发布，LICENSE 保留上游版权声明。

## 当前状态（2026-11-25）

✅ pronouncing 等价层 + ARPABET/IPA 增值层完整实现 · ✅ 上游官方 doctest 转写通过 ·
✅ 三后端各 48/48 测试通过 · ✅ `moon check` 0 error / 0 warning ·
✅ CLI 8 子命令 + `--json` / `--batch` JSON Lines · ✅ 词典数据由 Node 脚本生成（可复现）·
✅ CI：三后端测试 + fmt/check/接口校验 + CLI/demo/差分回归 ·
✅ **差分对拍**：5967 查询逐字段一致，未预期不一致 0 ·
✅ **覆盖率报告**：[`COVERAGE.md`](COVERAGE.md)——88 行未覆盖（2 行防御分支 + CLI/web 走独立进程集成测试），`arpabet.mbt` 0 未覆盖（39 音素全验证）·
✅ **变更历史**：[`CHANGELOG.md`](CHANGELOG.md)——0.1.0 至 0.1.2 逐条记录 ·
✅ `demo/` 浏览器词典页：js 后端 ES module，查询不离开页面，推送 main 自动部署 Pages。

---

<a id="papery0pronouncing-en"></a>

## PaperY0/pronouncing (EN)

A MoonBit port of the CMU Pronouncing Dictionary (CMUdict 0.7b, 133,852 entries) plus
Allison Parrish's [pronouncing](https://github.com/aparrish/pronouncingpy), with an
**ARPABET↔IPA** value-add. Look up a word's ARPABET pronunciation, stress pattern, syllable
count, rhyming part and rhymes; search the whole dictionary by pronunciation or stress regex;
convert ARPABET to IPA. Pure computation, no IO; wasm / wasm-gc / js targets verified in CI.

```moonbit nocheck
@pronouncing.phones_for_word("permit")   // ["P ER0 M IH1 T", "P ER1 M IH2 T"]
@pronouncing.rhymes("conditioner")       // ["commissioner", "parishioner", "petitioner", "practitioner"]
@pronouncing.arpabet_to_ipa("P ER0 M IH1 T")  // "p ɚ m ɪ t"
@pronouncing.ipa_for_word("permit")      // ["p ɚ m ɪ t", "p ɝ m ɪ t"]
```

**Install & minimal example** (published on [mooncakes.io](https://mooncakes.io/docs/PaperY0/pronouncing)):

```bash
moon new hello_pronouncing && cd hello_pronouncing
moon add PaperY0/pronouncing
```

Add `"PaperY0/pronouncing" @pronouncing` to `cmd/main/moon.pkg` imports, put the snippet below
in `cmd/main/main.mbt`, then `moon run cmd/main` — verified against the published 0.1.2:

```moonbit nocheck
///|
fn main {
  let phones = @pronouncing.phones_for_word("permit")
  for p in phones {
    println(p)
  }
  println(@pronouncing.arpabet_to_ipa(phones[0]))
  for ipa in @pronouncing.ipa_for_word("permit") {
    println(ipa)
  }
}
```

**Ecosystem gap:** `moon search` for cmudict / arpabet / pronouncing / phoneme / g2p / rhyme
returns no modules; the only adjacent module (`moonbit-phonetic`) does Soundex/Metaphone name
hashing, a different domain. Zero functional overlap with any existing module.

Two deliberate differences from upstream (both documented in DIFF-REPORT): phones are
normalized to single spaces (semantically equivalent, matches upstream doctests), and `rhymes`
excludes the word itself case-insensitively (fixes an upstream footgun). String sorting uses
`String::lexical_compare` because MoonBit's `Compare for String` is shortlex, not lexicographic.

Dictionary data: CMUdict 0.7b (BSD-like, (c) Carnegie Mellon University). Algorithms:
`aparrish/pronouncingpy` (BSD-3-Clause, (c) 2015 Allison Parrish; full text in LICENSE). This project: MIT. 48 tests pass on each of the three backends;
a 5967-query differential against upstream shows zero unexpected mismatches.