# demo/ — 浏览器发音词典

最小可用示例：输入一个英文词，实时显示 ARPABET 发音、IPA 转写、重音模式、音节数、
押韵部与押韵词；也可用发音/重音正则搜索整个词典。

**查询不离开浏览器**：`demo/pronouncing.js` 是 MoonBit 核心库编译到 js 后端的产物，
全部计算在本地 Worker 中完成，查询时不发送任何数据。初次加载页面、Worker 和引擎等
静态资源仍会产生网络请求。

为保持演示页可响应，输入最多 256 个 Unicode 标量值；超限会显示错误。输入防抖 150 ms，
过期请求的响应不会覆盖新输入。正则搜索可能命中上万词，页面只渲染前 500 个。

## 跑起来

```bash
bash demo/build.sh                       # 生成 demo/pronouncing.js（约 3.7 MB，含 133,852 条目）
python -m http.server -d demo 8000       # ES module 需要 http://，file:// 不行
# 打开 http://localhost:8000/
```

## 在线版本

推送到 main 后由 `.github/workflows/pages.yml` 自动部署到 GitHub Pages。

## 结构

| 文件 | 作用 |
| --- | --- |
| `web/pronouncing_web.mbt` | MoonBit 侧唯一导出：`pronouncingReport(op, arg) -> String`（JSON） |
| `web/moon.pkg` | `pkgtype: foreign_library` + `link.js { format: esm }` |
| `index.html` / `app.js` / `style.css` | 前端 |
| `worker.js` | 输入预算、后台查询及结构化结果/错误 |
| `pronouncing.js` | **生成文件**，勿手改 |

## 为什么是这个构建方式

与 zxcvbn-MoonBit 同一套实测结论：

1. **必须用 `foreign_library` + `link.js.format = "esm"`。** js 后端默认只给可执行包出
   IIFE（会立刻执行 main，浏览器用不了）；foreign_library 配 esm 才产出带 `export` 的 ES module。
2. **值编组只对简单类型有效。** `String` ↔ JS string 自动；结构体无编组，故导出函数返回
   JSON 字符串，Worker 内 `JSON.parse`。
3. **导出名要显式 `#export_name("pronouncingReport")`**，否则是编译器 mangling 后的名字。
4. **本 demo 用 js 目标。** wasm-gc / wasm 后端的能力由 CI 的三后端测试矩阵覆盖。

## 许可

词典为 CMUdict 0.7b（BSD-like，(c) Carnegie Mellon University），算法来自
`aparrish/pronouncingpy`（BSD-3-Clause, (c) 2015 Allison Parrish，全文见根目录
LICENSE），本项目以 MIT 发布。