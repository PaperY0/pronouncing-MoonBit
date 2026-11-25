#!/usr/bin/env python
"""pronouncing-MoonBit 对上游 Python pronouncing 的逐字段差分对拍（CI 权威基准）。

用法（仓库根目录）：
    pip install pronouncing cmudict
    python tools/diff_test.py              # 跑对拍，写 DIFF-REPORT.md
    python tools/diff_test.py --no-report  # 只跑，结论打到 stdout

基准是 aparrish/pronouncingpy（MIT）真正的 Python 包，而非任何二次移植。
本地无 Python 时用 tools/diff_test.mjs（对忠实 JS 移植），两者算法同源。

两处刻意差异同样施加于参考侧，以隔离验证算法本身（见 README / DIFF-REPORT）：
  ① phones 规范化：把喂给 pronouncing 的数据流折叠成单空格（与本项目嵌入数据、
     上游 doctest 的干净输出一致），避免 SourceForge 原始两空格带来的前导空格，
     从而 rhyming_part 的 fallback 分支押韵键一致。
  ② rhymes 自身排除按小写：参考侧用 pronouncing.rhymes(arg.lower())，等价于本库
     的小写自身排除，修正上游大小写敏感 footgun。
"""
from __future__ import annotations

import argparse
import io
import json
import os
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO_ROOT, "data", "upstream", "cmudict-0.7b")
CORPUS = os.path.join(REPO_ROOT, "tools", "corpus.json")

FIELDS = {
    "phones": ["phones"], "rhymes": ["rhymes"], "syllables": ["syllables"],
    "stress": ["stresses"], "search": ["words"], "stresses": ["words"],
    "info": ["phones", "stresses", "syllables", "rhyming_parts"],
}


def norm(s: str) -> str:
    return " ".join(s.split())


def load_pronouncing():
    import pronouncing
    buf = io.BytesIO()
    with open(DATA, encoding="latin-1") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(";"):
                continue
            word, phones = line.split(" ", 1)
            buf.write((word + " " + norm(phones) + "\n").encode("utf-8"))
    buf.seek(0)
    pronouncing.init_cmu(buf)
    return pronouncing


def sample_words() -> list[str]:
    out, i = [], 0
    with open(DATA, encoding="latin-1") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(";"):
                continue
            if i % 997 == 0:
                out.append(line.split(" ", 1)[0].split("(", 1)[0].lower())
            i += 1
    return out


def build_queries():
    with open(CORPUS, encoding="utf-8") as f:
        corpus = json.load(f)
    words = list(dict.fromkeys(corpus["words"] + sample_words()))
    qs = []
    for w in words:
        for op in ("phones", "rhymes", "syllables", "stress", "info"):
            qs.append({"op": op, "arg": w})
    for p in corpus["search_patterns"]:
        qs.append({"op": "search", "arg": p})
    for p in corpus["stress_patterns"]:
        qs.append({"op": "stresses", "arg": p})
    return words, corpus, qs


def run_moonbit(qs, chunk=200):
    by_op = {}
    for i, q in enumerate(qs):
        by_op.setdefault(q["op"], []).append(i)
    results = [None] * len(qs)
    for op, idxs in by_op.items():
        for s in range(0, len(idxs), chunk):
            ci = idxs[s:s + chunk]
            cmd = ["moon", "run", "--release", "cmd/main", "--", "--batch", "--json", op, "--"]
            cmd += [qs[i]["arg"] for i in ci]
            proc = subprocess.run(cmd, cwd=REPO_ROOT, capture_output=True, text=True, encoding="utf-8")
            if proc.returncode != 0:
                raise RuntimeError(f"CLI 失败 op={op} (exit {proc.returncode}):\n{proc.stderr[-2000:]}")
            lines = [l for l in proc.stdout.splitlines() if l.strip()]
            if len(lines) != len(ci):
                raise RuntimeError(f"输出行数不符 op={op}：期望 {len(ci)}，实得 {len(lines)}")
            for i, l in zip(ci, lines):
                results[i] = json.loads(l)
    return results


def run_reference(pr, qs):
    out = []
    for q in qs:
        op, arg = q["op"], q["arg"]
        if op == "phones":
            r = {"op": op, "word": arg, "phones": [norm(p) for p in pr.phones_for_word(arg)]}
        elif op == "rhymes":
            r = {"op": op, "word": arg, "rhymes": pr.rhymes(arg.lower())}
        elif op == "syllables":
            r = {"op": op, "word": arg, "syllables": [pr.syllable_count(p) for p in pr.phones_for_word(arg)]}
        elif op == "stress":
            r = {"op": op, "word": arg, "stresses": pr.stresses_for_word(arg)}
        elif op == "search":
            r = {"op": op, "pattern": arg, "words": pr.search(arg)}
        elif op == "stresses":
            r = {"op": op, "pattern": arg, "words": pr.search_stresses(arg)}
        elif op == "info":
            ps = pr.phones_for_word(arg)
            r = {"op": op, "word": arg, "phones": [norm(p) for p in ps],
                 "stresses": [pr.stresses(p) for p in ps],
                 "syllables": [pr.syllable_count(p) for p in ps],
                 "rhyming_parts": [norm(pr.rhyming_part(p)) for p in ps]}
        else:
            raise ValueError(op)
        out.append(r)
    return out


def compare(q, o, t):
    ms = []
    for f in FIELDS[q["op"]]:
        a = json.dumps(o.get(f), ensure_ascii=False)
        b = json.dumps(t.get(f), ensure_ascii=False)
        if a != b:
            ms.append((q["op"], q["arg"], f, o.get(f), t.get(f)))
    return ms


def esc(v) -> str:
    s = json.dumps(v, ensure_ascii=False)
    return "`" + s.replace("\\", "\\\\").replace("|", "\\|")[:120] + "`"


def write_report(path, words, corpus, qs, ms, bad):
    L = []
    L.append("# DIFF-REPORT：pronouncing-MoonBit 对上游 pronouncing 差分对拍\n")
    L.append("生成方式：`python tools/diff_test.py`（CI，对真正的 Python pronouncing 包）；本地可用 `node tools/diff_test.mjs`。\n")
    L.append("## 一、基准选择\n")
    L.append("对拍基准是 **aparrish/pronouncingpy**（MIT）真正的 Python 包，即 CMUdict 之上那层薄算法的官方出处，而非任何二次移植。\n")
    L.append("## 二、用例构成\n")
    L.append(f"- 词数：**{len(words)}**（精选语料 {len(corpus['words'])} + 每 997 条目系统抽样，去重）")
    L.append("- 每词跑 phones / rhymes / syllables / stress / info 五种查询")
    L.append(f"- search 正则 {len(corpus['search_patterns'])} 条、search_stresses 正则 {len(corpus['stress_patterns'])} 条")
    L.append(f"- 查询总数：**{len(qs)}**\n")
    L.append("## 三、比较口径\n")
    L.append("| 字段 | 口径 |")
    L.append("| --- | --- |")
    L.append("| phones / rhymes / syllables / stresses / words / rhyming_parts | 精确相等（含顺序与重复） |")
    L.append("| phones / rhyming_parts | 两侧均规范化为单空格后比较（差异①） |")
    L.append("| info 的 ipa 字段 | 不参与对拍（上游无 IPA，属增值功能，由 arpabet_test.mbt 单测覆盖） |\n")
    L.append("## 四、结果\n")
    L.append(f"- 查询总数：**{len(qs)}**")
    L.append(f"- 完全一致：**{len(qs) - len(bad)}**")
    L.append(f"- 字段级偏差：**{len(ms)}**\n")
    if ms:
        L.append("### 偏差明细（前 60 条）\n")
        L.append("| op | arg | 字段 | 本库 | 上游 |")
        L.append("| --- | --- | --- | --- | --- |")
        for op, arg, f, o, t in ms[:60]:
            L.append(f"| {op} | {esc(arg)} | {f} | {esc(o)} | {esc(t)} |")
        L.append("")
    else:
        L.append("**未预期不一致为 0**——本库与上游在全部查询上逐字段一致（规范化口径内）。\n")
    L.append("## 五、与上游的刻意差异\n")
    L.append("1. **phones 单空格规范化**：SourceForge 原始 cmudict-0.7b 词与音素间是两空格，上游 `split(' ', 1)` 会留下前导空格；本库折叠为单空格，语义等价且匹配上游 doctest 的干净输出。")
    L.append("2. **rhymes 自身排除按小写**：上游用原始大小写比较，传入大写词时不排除自身；本库统一小写，修正该 footgun。\n")
    L.append("## 六、复现\n")
    L.append("```bash")
    L.append("pip install pronouncing cmudict")
    L.append("python tools/diff_test.py")
    L.append("```\n")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L))
    print(f"\n报告已写入 {path}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-report", action="store_true")
    ap.add_argument("--report", default=os.path.join(REPO_ROOT, "DIFF-REPORT.md"))
    args = ap.parse_args()
    pr = load_pronouncing()
    words, corpus, qs = build_queries()
    print(f"词数: {len(words)}（精选 {len(corpus['words'])} + 系统抽样，去重后）")
    print(f"查询总数: {len(qs)}")
    ours = run_moonbit(qs)
    theirs = run_reference(pr, qs)
    ms = []
    for q, o, t in zip(qs, ours, theirs):
        ms += compare(q, o, t)
    bad = {(m[0], m[1]) for m in ms}
    print(f"\n完全一致查询: {len(qs) - len(bad)}/{len(qs)}")
    print(f"字段级偏差: {len(ms)}")
    for m in ms[:20]:
        op, arg, f, o, t = m
        print("  ", op, repr(arg), f)
        if isinstance(o, list) and isinstance(t, list):
            so, st = set(o), set(t)
            print("      len ours/theirs:", len(o), len(t))
            print("      only ours:", sorted(so - st)[:40])
            print("      only theirs:", sorted(st - so)[:40])
            if so == st and o != t:
                print("      same set, ORDER/DUP differs")
        else:
            print("      ours:", o, "theirs:", t)
    if not args.no_report:
        write_report(args.report, words, corpus, qs, ms, bad)
    return 1 if ms else 0


if __name__ == "__main__":
    sys.exit(main())