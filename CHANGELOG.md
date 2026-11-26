# Changelog

本项目的所有显著变更记录于此。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [0.1.2] - 2026-11-26

### Added
- `ipa_for_word(word)` 便捷 API：一次调用返回一个词全部发音的 IPA 转写（重音感知）。
- CLI 集成测试（`tools/test_cli.mjs`，16 例）：8 子命令 JSON 契约、人类可读输出、`--help` / `--batch`、
  参数错误非零退出、`déjà` latin-1 回归；已接入 CI integration job。
- CI 新增 coverage job：`moon coverage analyze` 带插桩跑测试，未覆盖行清单上传为 artifact（口径见 COVERAGE.md）。
- 跨 API 性质测试（`properties_test.mbt`）：音素编辑距离的度量性质（同一性/对称性/三角不等式/到空串距离）、
  元音辅音 inventory 自洽性、`search` 词边界语义、`search_stresses` 锚定匹配、返回值副本隔离、`rhyming_part` fallback 边界。

### Fixed
- 上游许可证归属修正：`aparrish/pronouncingpy` 实为 **BSD-3-Clause**（此前误标 MIT）。
  LICENSE 现附其完整许可证文本；源码注释、README、对拍工具与报告中的标注一并更正。

## [0.1.1] - 2026-11-25

### Fixed
- CMUdict 0.7b 源文件按 **latin-1** 而非 UTF-8 解码（生成器 `tools/gen_cmudict.mjs`、
  JS 参考实现 `tools/ref/pronouncing_ref.mjs`、对拍脚本 `tools/diff_test.mjs` / `tools/diff_test.py`）。
  此前全词典唯一非 ASCII 词条 `DÉJÀ` 被读成乱码，导致 3 处差分偏差（rhymes law/raw、search AA1）。
- 重新生成嵌入数据（133,852 条、34 块不变，仅 1 行变更）；修复后差分对拍 5,967 查询 **0 偏差**。

> 0.1.0 因含乱码数据已被本版本取代；mooncakes 注册表不允许覆盖同版本，故以 0.1.1 发布。

## [0.1.0] - 2026-11-25

### Added
- CMUdict 0.7b 全量嵌入（133,852 条发音、34 个数据块），`Lazy` 惰性建索引。
- pronouncing 等价 API：`phones_for_word` / `stresses` / `stresses_for_word` / `syllable_count` /
  `rhyming_part` / `rhymes` / `search` / `search_stresses` / `entry_count` / `word_count`。
- ARPABET→IPA 增值层：`arpabet_to_ipa` / `phone_to_ipa` / `phone_kind` / `is_vowel` /
  `strip_stress` / `stress_of` / `phone_edit_distance` / 元音辅音 inventory。
- CLI（8 子命令，`--json` / `--batch` / `--help`）与浏览器 demo（本地 Worker，查询不出网）。
- 差分对拍工具链：对真 Python `pronouncing` 包（CI）与忠实 JS 移植（本地）双重基准。
- 40 个测试在 wasm / wasm-gc / js 三后端全过；CI（构建矩阵 + 接口一致性 + 集成对拍）与 Pages 部署。

[0.1.2]: https://github.com/PaperY0/pronouncing-MoonBit/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/PaperY0/pronouncing-MoonBit/releases/tag/v0.1.1
[0.1.0]: https://github.com/PaperY0/pronouncing-MoonBit/commit/3b6883e