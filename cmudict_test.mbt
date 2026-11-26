// Black-box tests：公共 API 行为。
// 向量来源：Allison Parrish `pronouncing` 的官方 doctest（与 CMUdict 0.7b 一致），
// 加本项目边界用例。

///|
test "phones_for_word/permit (official doctest)" {
  assert_eq(@pronouncing.phones_for_word("permit"), [
    "P ER0 M IH1 T", "P ER1 M IH2 T",
  ])
}

///|
test "phones_for_word/case insensitive" {
  assert_eq(
    @pronouncing.phones_for_word("PERMIT"),
    @pronouncing.phones_for_word("permit"),
  )
}

///|
test "phones_for_word/unknown word returns empty" {
  assert_eq(@pronouncing.phones_for_word("zzzznotaword"), [])
}

///|
test "phones_for_word/returns independent copy" {
  let a = @pronouncing.phones_for_word("permit")
  a.push("caller-owned")
  assert_eq(@pronouncing.phones_for_word("permit").length(), 2)
}

///|
test "syllable_count/literally (official doctest)" {
  let phones = @pronouncing.phones_for_word("literally")
  assert_eq(@pronouncing.syllable_count(phones[0]), 4)
}

///|
test "stresses/obsequious (official doctest)" {
  let phones = @pronouncing.phones_for_word("obsequious")
  assert_eq(@pronouncing.stresses(phones[0]), "0100")
}

///|
test "stresses_for_word/permit (official doctest)" {
  assert_eq(@pronouncing.stresses_for_word("permit"), ["01", "12"])
}

///|
test "stresses/only keeps 0 1 2" {
  assert_eq(@pronouncing.stresses("P ER0 M IH1 T"), "01")
  assert_eq(@pronouncing.stresses(""), "")
  assert_eq(@pronouncing.stresses("B CH D"), "")
}

///|
test "syllable_count/empty and consonants" {
  assert_eq(@pronouncing.syllable_count(""), 0)
  assert_eq(@pronouncing.syllable_count("B CH D"), 0)
}

///|
test "rhyming_part/purple (official doctest)" {
  let phones = @pronouncing.phones_for_word("purple")
  assert_eq(@pronouncing.rhyming_part(phones[0]), "ER1 P AH0 L")
}

///|
test "rhyming_part/index 0 is never checked" {
  // 唯一带重音的元音在 index 0：上游 range(len-1,0,-1) 不含 0，返回整串。
  assert_eq(@pronouncing.rhyming_part("AH1 P AH0 L"), "AH1 P AH0 L")
}

///|
test "rhyming_part/no stressed vowel returns whole" {
  assert_eq(@pronouncing.rhyming_part("P AH0 L"), "P AH0 L")
  assert_eq(@pronouncing.rhyming_part("B"), "B")
  assert_eq(@pronouncing.rhyming_part(""), "")
}

///|
test "rhymes/conditioner (official doctest)" {
  assert_eq(@pronouncing.rhymes("conditioner"), [
    "commissioner", "parishioner", "petitioner", "practitioner",
  ])
}

///|
test "rhymes/unknown word returns empty" {
  assert_eq(@pronouncing.rhymes("zzzznotaword"), [])
}

///|
test "rhymes/excludes self case-insensitively" {
  let r = @pronouncing.rhymes("permit")
  assert_true(r.iter().any(w => w == "permit") == false)
  // 大写查询也能排除自身（刻意修正上游大小写敏感排除的 footgun）
  let r2 = @pronouncing.rhymes("PERMIT")
  assert_true(r2.iter().any(w => w == "permit") == false)
}

///|
test "rhymes/sorted and unique" {
  let r = @pronouncing.rhymes("conditioner")
  let mut ok = true
  for i in 1..<r.length() {
    // 纯字典序严格递增（MoonBit 的 `>` 是 shortlex，不能用来验证字典序）
    if String::lexical_compare(r[i - 1], r[i]) >= 0 {
      ok = false
    }
  }
  assert_true(ok)
}

///|
test "search/interpolate (official doctest)" {
  let words = @pronouncing.search("ER1 P AH0") catch { _ => [] }
  assert_true(words.iter().any(w => w == "interpolate"))
}

///|
test "search_stresses/gubernatorial (official doctest)" {
  let words = @pronouncing.search_stresses("020120") catch { _ => [] }
  assert_eq(words, ["gubernatorial"])
}

///|
test "search/word boundary rejects mid-token match" {
  // "R1" 不应匹配 "ER1"（R1 在词内部，无词边界）。
  let words = @pronouncing.search("R1") catch { _ => [] }
  // 所有命中词的发音里 R1 都必须独立成 token（前面是空格或串首）。
  // 这里只验证不会把 "ER1" 这类含 R1 但非边界的发音误报：检查一个已知词。
  let permit = @pronouncing.search("ER1") catch { _ => [] }
  assert_true(permit.iter().any(w => w == "permit"))
  assert_true(words.iter().any(w => w == "permit") == false)
}

///|
test "search/invalid regex raises InvalidRegex" {
  let mut raised = false
  let _words = @pronouncing.search("[") catch {
    InvalidRegex(_) => {
      raised = true
      []
    }
  }
  assert_true(raised)
}

///|
test "counts/entry and word counts" {
  assert_eq(@pronouncing.entry_count(), 133852)
  assert_true(@pronouncing.word_count() > 100000)
}

///|
test "ipa_for_word/permit both pronunciations" {
  assert_eq(@pronouncing.ipa_for_word("permit"), ["p ɚ m ɪ t", "p ɝ m ɪ t"])
  // 大小写不敏感，与 phones_for_word 一致
  assert_eq(
    @pronouncing.ipa_for_word("PERMIT"),
    @pronouncing.ipa_for_word("permit"),
  )
}

///|
test "ipa_for_word/unknown word and composition law" {
  assert_eq(@pronouncing.ipa_for_word("zzznotaword"), [])
  // 组合律：ipa_for_word == phones_for_word 逐条 arpabet_to_ipa
  for w in ["orange", "banana", "computer", "water"] {
    let expected = @pronouncing.phones_for_word(w).map(
      @pronouncing.arpabet_to_ipa,
    )
    assert_eq(@pronouncing.ipa_for_word(w), expected)
  }
}
