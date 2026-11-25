// ARPABET 音素系统：inventory、发音方式分类、重音处理、ARPABET→IPA 转换、
// 音素编辑距离。这些是 pronouncing 之外的增值能力（pronouncing 不做 IPA）。
//
// 音素集与分类来自 data/upstream/cmudict-0.7b.symbols / cmudict-0.7b.phones。
// ARPABET→IPA 采用标准 CMU/IPA 对应；AH/ER 按重音区分（轻声 → ə/ɚ）。

///|
/// 音素的发音方式分类（与 cmudict-0.7b.phones 一致）。
#derive(Eq, Debug)
pub(all) enum PhoneKind {
  Vowel
  Stop
  Affricate
  Fricative
  Aspirate
  Liquid
  Nasal
  Semivowel
}

///|
/// 15 个 ARPABET 元音（不带重音数字的基础形）。
pub let arpabet_vowels : Array[String] = [
  "AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY", "IH", "IY", "OW", "OY", "UH",
  "UW",
]

///|
/// 24 个 ARPABET 辅音。
pub let arpabet_consonants : Array[String] = [
  "B", "CH", "D", "DH", "F", "G", "HH", "JH", "K", "L", "M", "N", "NG", "P", "R",
  "S", "SH", "T", "TH", "V", "W", "Y", "Z", "ZH",
]

///|
/// 去掉音素 token 末尾的重音数字："AH0" → "AH"，"B" → "B"。
pub fn strip_stress(phone : String) -> String {
  let chars = phone.to_array()
  if chars.length() > 0 {
    let last = chars[chars.length() - 1]
    if last == '0' || last == '1' || last == '2' {
      return String::from_array(chars[0:chars.length() - 1])
    }
  }
  phone
}

///|
/// 取音素 token 的重音数字（0/1/2）；辅音或无重音返回 None。
pub fn stress_of(phone : String) -> Int32? {
  let chars = phone.to_array()
  if chars.length() > 0 {
    let last = chars[chars.length() - 1]
    if last == '0' {
      return Some(0)
    }
    if last == '1' {
      return Some(1)
    }
    if last == '2' {
      return Some(2)
    }
  }
  None
}

///|
/// 是否元音（按基础形判断，忽略重音）。
pub fn is_vowel(phone : String) -> Bool {
  match strip_stress(phone) {
    "AA"
    | "AE"
    | "AH"
    | "AO"
    | "AW"
    | "AY"
    | "EH"
    | "ER"
    | "EY"
    | "IH"
    | "IY"
    | "OW"
    | "OY"
    | "UH"
    | "UW" => true
    _ => false
  }
}

///|
/// 音素的发音方式分类；未知音素返回 None。
pub fn phone_kind(phone : String) -> PhoneKind? {
  match strip_stress(phone) {
    "AA"
    | "AE"
    | "AH"
    | "AO"
    | "AW"
    | "AY"
    | "EH"
    | "ER"
    | "EY"
    | "IH"
    | "IY"
    | "OW"
    | "OY"
    | "UH"
    | "UW" => Some(Vowel)
    "B" | "D" | "G" | "K" | "P" | "T" => Some(Stop)
    "CH" | "JH" => Some(Affricate)
    "DH" | "F" | "S" | "SH" | "TH" | "V" | "Z" | "ZH" => Some(Fricative)
    "HH" => Some(Aspirate)
    "L" | "R" => Some(Liquid)
    "M" | "N" | "NG" => Some(Nasal)
    "W" | "Y" => Some(Semivowel)
    _ => None
  }
}

///|
/// 单个 ARPABET 音素（可带重音数字）→ IPA。未知音素返回 None。
///
/// AH/ER 按重音区分：轻声（0）→ ə/ɚ，重读（1/2）→ ʌ/ɝ。
/// 其余元音/辅音用标准对应。
pub fn phone_to_ipa(phone : String) -> String? {
  let base = strip_stress(phone)
  let unstressed = stress_of(phone) is Some(0)
  match base {
    "AA" => Some("ɑ")
    "AE" => Some("æ")
    "AH" => Some(if unstressed { "ə" } else { "ʌ" })
    "AO" => Some("ɔ")
    "AW" => Some("aʊ")
    "AY" => Some("aɪ")
    "EH" => Some("ɛ")
    "ER" => Some(if unstressed { "ɚ" } else { "ɝ" })
    "EY" => Some("eɪ")
    "IH" => Some("ɪ")
    "IY" => Some("i")
    "OW" => Some("oʊ")
    "OY" => Some("ɔɪ")
    "UH" => Some("ʊ")
    "UW" => Some("u")
    "B" => Some("b")
    "CH" => Some("tʃ")
    "D" => Some("d")
    "DH" => Some("ð")
    "F" => Some("f")
    "G" => Some("ɡ")
    "HH" => Some("h")
    "JH" => Some("dʒ")
    "K" => Some("k")
    "L" => Some("l")
    "M" => Some("m")
    "N" => Some("n")
    "NG" => Some("ŋ")
    "P" => Some("p")
    "R" => Some("ɹ")
    "S" => Some("s")
    "SH" => Some("ʃ")
    "T" => Some("t")
    "TH" => Some("θ")
    "V" => Some("v")
    "W" => Some("w")
    "Y" => Some("j")
    "Z" => Some("z")
    "ZH" => Some("ʒ")
    _ => None
  }
}

///|
/// 把一整串 phones（空格分隔的 ARPABET）转成 IPA（空格分隔）。
/// 未知 token 原样保留。
pub fn arpabet_to_ipa(phones : String) -> String {
  let out : Array[String] = []
  for tok in phone_tokens(phones) {
    match phone_to_ipa(tok) {
      Some(ipa) => out.push(ipa)
      None => out.push(tok)
    }
  }
  join_str(out, " ")
}

///|
/// 两串 phones 的音素编辑距离（Levenshtein，按音素 token 计，忽略重音数字）。
///
/// 用于发音相似度：距离越小越接近。比较前去掉重音数字，使 "IH0"/"IH1"
/// 视为同一音素（重音差异不计入距离）。
pub fn phone_edit_distance(a : String, b : String) -> Int32 {
  let ta = phone_tokens(a).map(t => strip_stress(t))
  let tb = phone_tokens(b).map(t => strip_stress(t))
  let m = ta.length()
  let n = tb.length()
  let mut prev : Array[Int32] = []
  let mut j = 0
  while j <= n {
    prev.push(j)
    j += 1
  }
  let mut i = 1
  while i <= m {
    let curr : Array[Int32] = [i]
    let mut k = 1
    while k <= n {
      let cost = if ta[i - 1] == tb[k - 1] { 0 } else { 1 }
      let del = prev[k] + 1
      let ins = curr[k - 1] + 1
      let sub = prev[k - 1] + cost
      let mut best = del
      if ins < best {
        best = ins
      }
      if sub < best {
        best = sub
      }
      curr.push(best)
      k += 1
    }
    prev = curr
    i += 1
  }
  prev[n]
}
