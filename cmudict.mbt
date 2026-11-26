// 公共 API：CMU 发音词典查询与 pronouncing 算法移植。
//
// 移植来源：Allison Parrish 的 `pronouncing`（Python, BSD-3-Clause）
//   https://github.com/aparrish/pronouncingpy
// 数据来源：CMU Pronouncing Dictionary 0.7b（(c) Carnegie Mellon University）
//   见 data/README.md。数据本体在 cmudict_data.mbt（由 tools/gen_cmudict.mjs 生成）。
//
// 与 pronouncing 的算法逐一对齐：phones_for_word / stresses / syllable_count /
// rhyming_part / rhymes / search / search_stresses。刻意差异见 README。

///|
/// 查询/搜索时的错误（正则非法等）。
#derive(Eq, Debug)
pub suberror PronouncingError {
  InvalidRegex(String)
}

///|
/// 词典的三种索引，首次使用时惰性构建。
///
/// - `pronunciations`：保序的 (word, phones) 列表，与上游文件行序一致，
///   供 search / search_stresses 按字典序遍历（含同一词的多个发音）。
/// - `lookup`：word → 该词全部发音（phones 字符串数组）。
/// - `rhyme_lookup`：rhyming_part → 拥有该押韵部的词数组。
priv struct DictData {
  pronunciations : Array[(String, String)]
  lookup : Map[String, Array[String]]
  rhyme_lookup : Map[String, Array[String]]
}

///|
let data : Lazy[DictData] = Lazy(() => build_data())

///|
/// 从嵌入数据构建三种索引。解析规则与 pronouncing.parse_cmu 对齐：
/// headword 已小写去 '(n)' 后缀，phones 已单空格规范化（生成器完成）。
fn build_data() -> DictData {
  let lines = cmudict_lines()
  let pronunciations : Array[(String, String)] = []
  let lookup : Map[String, Array[String]] = Map([])
  let rhyme_lookup : Map[String, Array[String]] = Map([])
  for line in lines {
    let (word, phones) = split_entry(line)
    if phones.length() == 0 {
      continue
    }
    pronunciations.push((word, phones))
    match lookup.get(word) {
      Some(arr) => arr.push(phones)
      None => lookup[word] = [phones]
    }
    let rp = rhyming_part(phones)
    match rhyme_lookup.get(rp) {
      Some(arr) => arr.push(word)
      None => rhyme_lookup[rp] = [word]
    }
  }
  { pronunciations, lookup, rhyme_lookup, }
}

///|
/// 把一行 "headword phones" 切成二元组（按第一个空格）。
fn split_entry(line : String) -> (String, String) {
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() && chars[i] != ' ' {
    i += 1
  }
  let word = String::from_array(chars[0:i])
  let phones = if i < chars.length() {
    String::from_array(chars[i + 1:])
  } else {
    ""
  }
  (word, phones)
}

///|
/// 把 phones 字符串按空格切成音素 token 数组（过滤空串）。
fn phone_tokens(phones : String) -> Array[String] {
  let out : Array[String] = []
  for tok in phones.split(" ") {
    let s = tok.to_owned()
    if s.length() > 0 {
      out.push(s)
    }
  }
  out
}

///|
/// 用分隔符连接字符串数组。
fn join_str(parts : ArrayView[String], sep : String) -> String {
  let out : Array[Char] = []
  let mut i = 0
  while i < parts.length() {
    if i > 0 {
      for c in sep.to_array() {
        out.push(c)
      }
    }
    for c in parts[i].to_array() {
      out.push(c)
    }
    i += 1
  }
  String::from_array(out)
}

///|
/// 纯字典序包装。MoonBit 内置 `Compare for String` 是 shortlex（先比长度再比内容），
/// 与 Python `sorted()` 的纯字典序不一致；用 `String::lexical_compare` 对齐上游语义。
#derive(Eq)
priv struct LexWord {
  word : String
}

///|
impl Compare for LexWord with fn compare(self, other) {
  String::lexical_compare(self.word, other.word)
}

///|
/// 排序去重（rhymes/search 输出语义：sorted(set(...))，纯字典序）。
fn sorted_unique(arr : Array[String]) -> Array[String] {
  let set = @sorted_set.SortedSet::from_iter(
    arr.iter().map(w => LexWord::{ word: w, }),
  )
  set.to_array().map(lw => lw.word)
}

///|
/// 词条总数（含同一词的多个发音变体，与上游文件非注释行数一致）。
pub fn entry_count() -> Int32 {
  data.force().pronunciations.length()
}

///|
/// 不同词的个数（lookup 的键数）。
pub fn word_count() -> Int32 {
  data.force().lookup.length()
}

///|
/// 取一个词的全部发音（phones 字符串数组）。
///
/// 对应 pronouncing.phones_for_word：查询前把词转小写；未命中返回空数组。
/// 返回的是副本，调用方可自由修改而不影响词典。
pub fn phones_for_word(word : String) -> Array[String] {
  match data.force().lookup.get(word.to_lower()) {
    Some(arr) => arr.map(p => p)
    None => []
  }
}

///|
/// 取一个 phones 字符串的重音模式（只保留 0/1/2 数字，保序）。
///
/// 对应 pronouncing.stresses：`re.sub(r"[^012]", "", s)`。
/// 例：stresses("P ER0 M IH1 T") == "01"。
pub fn stresses(phones : String) -> String {
  let out : Array[Char] = []
  for c in phones.to_array() {
    if c == '0' || c == '1' || c == '2' {
      out.push(c)
    }
  }
  String::from_array(out)
}

///|
/// 一个词的全部重音模式（每个发音一个）。
///
/// 对应 pronouncing.stresses_for_word。
pub fn stresses_for_word(word : String) -> Array[String] {
  phones_for_word(word).map(p => stresses(p))
}

///|
/// 一个 phones 字符串的音节数 = 重音数字个数。
///
/// 对应 pronouncing.syllable_count：`len(stresses(phones))`。
pub fn syllable_count(phones : String) -> Int32 {
  stresses(phones).to_array().length()
}

///|
/// 取 phones 的“押韵部”：从最靠近词尾的带主/次重音（1 或 2）的元音
/// 一直到词尾。
///
/// 对应 pronouncing.rhyming_part：从末尾向前扫描（**不含 index 0**），
/// 找到第一个末字符为 '1' 或 '2' 的 token，返回该 token 起至词尾的子串；
/// 若没有这样的 token，返回整个 phones 字符串。
pub fn rhyming_part(phones : String) -> String {
  let tokens = phone_tokens(phones)
  let mut i = tokens.length() - 1
  while i >= 1 {
    let chars = tokens[i].to_array()
    if chars.length() > 0 {
      let last = chars[chars.length() - 1]
      if last == '1' || last == '2' {
        return join_str(tokens[i:], " ")
      }
    }
    i -= 1
  }
  phones
}

///|
/// 取与一个词押韵的词（排序去重，排除该词自身）。
///
/// 对应 pronouncing.rhymes：对该词每个发音取押韵部，查 rhyme_lookup，
/// 合并后排序去重。刻意差异：自身排除按小写比较（上游按原始输入大小写
/// 比较，大写查询时无法排除自身——这里修正，见 README）。
pub fn rhymes(word : String) -> Array[String] {
  let w = word.to_lower()
  let d = data.force()
  let phones_list = match d.lookup.get(w) {
    Some(a) => a
    None => []
  }
  if phones_list.length() == 0 {
    return []
  }
  let combined : Array[String] = []
  for ph in phones_list {
    let rp = rhyming_part(ph)
    match d.rhyme_lookup.get(rp) {
      Some(ws) =>
        for ww in ws {
          if ww != w {
            combined.push(ww)
          }
        }
      None => ()
    }
  }
  sorted_unique(combined)
}

///|
/// 是否词边界（复刻正则 `\b`：一侧是词字符 [A-Za-z0-9_]，另一侧不是）。
fn is_word_boundary(chars : Array[Char], pos : Int32) -> Bool {
  let before_word = pos > 0 && is_word_char(chars[pos - 1])
  let after_word = pos < chars.length() && is_word_char(chars[pos])
  before_word != after_word
}

///|
fn is_word_char(c : Char) -> Bool {
  c.is_ascii_uppercase() ||
  c.is_ascii_lowercase() ||
  c.is_ascii_digit() ||
  c == '_'
}

///|
/// 搜索发音匹配正则的词（保字典序，含重复——同一词多个发音命中会多次出现）。
///
/// 对应 pronouncing.search：`re.compile(r"\b" + pattern + r"\b").search(phones)`。
/// 这里用 core Regex 找匹配，再手动校验匹配两侧的词边界（等价于 `\b...\b`，
/// 与引擎的断言语法解耦）。pattern 非法时 raise InvalidRegex。
pub fn search(pattern : String) -> Array[String] raise PronouncingError {
  let re = @string.Regex(pattern) catch { _ => raise InvalidRegex(pattern) }
  let d = data.force()
  let out : Array[String] = []
  for entry in d.pronunciations {
    let phones = entry.1
    let chars = phones.to_array()
    let mut found = false
    for m in re.find(phones) {
      let s = m.before().length()
      let e = s + m.content().length()
      if is_word_boundary(chars, s) && is_word_boundary(chars, e) {
        found = true
        break
      }
    }
    if found {
      out.push(entry.0)
    }
  }
  out
}

///|
/// 搜索重音模式匹配正则的词（保字典序，含重复）。
///
/// 对应 pronouncing.search_stresses：`re.compile(pattern).search(stresses(phones))`，
/// **不加**词边界。
pub fn search_stresses(
  pattern : String,
) -> Array[String] raise PronouncingError {
  let re = @string.Regex(pattern) catch { _ => raise InvalidRegex(pattern) }
  let d = data.force()
  let out : Array[String] = []
  for entry in d.pronunciations {
    if re.execute(stresses(entry.1)) is Some(_) {
      out.push(entry.0)
    }
  }
  out
}
