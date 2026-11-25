// Black-box tests：ARPABET 音素系统、IPA 转换、音素编辑距离。

///|
test "strip_stress" {
  assert_eq(@pronouncing.strip_stress("AH0"), "AH")
  assert_eq(@pronouncing.strip_stress("ER1"), "ER")
  assert_eq(@pronouncing.strip_stress("B"), "B")
  assert_eq(@pronouncing.strip_stress("NG"), "NG")
  assert_eq(@pronouncing.strip_stress(""), "")
}

///|
test "stress_of" {
  assert_eq(@pronouncing.stress_of("AH0"), Some(0))
  assert_eq(@pronouncing.stress_of("AH1"), Some(1))
  assert_eq(@pronouncing.stress_of("AH2"), Some(2))
  assert_eq(@pronouncing.stress_of("B"), None)
  assert_eq(@pronouncing.stress_of(""), None)
}

///|
test "is_vowel" {
  assert_true(@pronouncing.is_vowel("AH0"))
  assert_true(@pronouncing.is_vowel("IY"))
  assert_true(@pronouncing.is_vowel("ER2"))
  assert_true(@pronouncing.is_vowel("B") == false)
  assert_true(@pronouncing.is_vowel("NG") == false)
}

///|
test "phone_kind" {
  assert_eq(@pronouncing.phone_kind("AA1"), Some(@pronouncing.PhoneKind::Vowel))
  assert_eq(@pronouncing.phone_kind("B"), Some(@pronouncing.PhoneKind::Stop))
  assert_eq(@pronouncing.phone_kind("T"), Some(@pronouncing.PhoneKind::Stop))
  assert_eq(
    @pronouncing.phone_kind("CH"),
    Some(@pronouncing.PhoneKind::Affricate),
  )
  assert_eq(
    @pronouncing.phone_kind("JH"),
    Some(@pronouncing.PhoneKind::Affricate),
  )
  assert_eq(
    @pronouncing.phone_kind("S"),
    Some(@pronouncing.PhoneKind::Fricative),
  )
  assert_eq(
    @pronouncing.phone_kind("TH"),
    Some(@pronouncing.PhoneKind::Fricative),
  )
  assert_eq(
    @pronouncing.phone_kind("HH"),
    Some(@pronouncing.PhoneKind::Aspirate),
  )
  assert_eq(@pronouncing.phone_kind("L"), Some(@pronouncing.PhoneKind::Liquid))
  assert_eq(@pronouncing.phone_kind("R"), Some(@pronouncing.PhoneKind::Liquid))
  assert_eq(@pronouncing.phone_kind("M"), Some(@pronouncing.PhoneKind::Nasal))
  assert_eq(@pronouncing.phone_kind("NG"), Some(@pronouncing.PhoneKind::Nasal))
  assert_eq(
    @pronouncing.phone_kind("W"),
    Some(@pronouncing.PhoneKind::Semivowel),
  )
  assert_eq(
    @pronouncing.phone_kind("Y"),
    Some(@pronouncing.PhoneKind::Semivowel),
  )
  assert_eq(@pronouncing.phone_kind("XX"), None)
}

///|
test "phone_to_ipa/vowels" {
  assert_eq(@pronouncing.phone_to_ipa("AA"), Some("ɑ"))
  assert_eq(@pronouncing.phone_to_ipa("AE"), Some("æ"))
  assert_eq(@pronouncing.phone_to_ipa("AO"), Some("ɔ"))
  assert_eq(@pronouncing.phone_to_ipa("AW"), Some("aʊ"))
  assert_eq(@pronouncing.phone_to_ipa("AY"), Some("aɪ"))
  assert_eq(@pronouncing.phone_to_ipa("EH"), Some("ɛ"))
  assert_eq(@pronouncing.phone_to_ipa("EY"), Some("eɪ"))
  assert_eq(@pronouncing.phone_to_ipa("IH"), Some("ɪ"))
  assert_eq(@pronouncing.phone_to_ipa("IY"), Some("i"))
  assert_eq(@pronouncing.phone_to_ipa("OW"), Some("oʊ"))
  assert_eq(@pronouncing.phone_to_ipa("OY"), Some("ɔɪ"))
  assert_eq(@pronouncing.phone_to_ipa("UH"), Some("ʊ"))
  assert_eq(@pronouncing.phone_to_ipa("UW"), Some("u"))
}

///|
test "phone_to_ipa/stress aware AH and ER" {
  assert_eq(@pronouncing.phone_to_ipa("AH0"), Some("ə"))
  assert_eq(@pronouncing.phone_to_ipa("AH1"), Some("ʌ"))
  assert_eq(@pronouncing.phone_to_ipa("AH2"), Some("ʌ"))
  assert_eq(@pronouncing.phone_to_ipa("ER0"), Some("ɚ"))
  assert_eq(@pronouncing.phone_to_ipa("ER1"), Some("ɝ"))
}

///|
test "phone_to_ipa/consonants (all 24)" {
  assert_eq(@pronouncing.phone_to_ipa("B"), Some("b"))
  assert_eq(@pronouncing.phone_to_ipa("CH"), Some("tʃ"))
  assert_eq(@pronouncing.phone_to_ipa("D"), Some("d"))
  assert_eq(@pronouncing.phone_to_ipa("DH"), Some("ð"))
  assert_eq(@pronouncing.phone_to_ipa("F"), Some("f"))
  assert_eq(@pronouncing.phone_to_ipa("G"), Some("ɡ"))
  assert_eq(@pronouncing.phone_to_ipa("HH"), Some("h"))
  assert_eq(@pronouncing.phone_to_ipa("JH"), Some("dʒ"))
  assert_eq(@pronouncing.phone_to_ipa("K"), Some("k"))
  assert_eq(@pronouncing.phone_to_ipa("L"), Some("l"))
  assert_eq(@pronouncing.phone_to_ipa("M"), Some("m"))
  assert_eq(@pronouncing.phone_to_ipa("N"), Some("n"))
  assert_eq(@pronouncing.phone_to_ipa("NG"), Some("ŋ"))
  assert_eq(@pronouncing.phone_to_ipa("P"), Some("p"))
  assert_eq(@pronouncing.phone_to_ipa("R"), Some("ɹ"))
  assert_eq(@pronouncing.phone_to_ipa("S"), Some("s"))
  assert_eq(@pronouncing.phone_to_ipa("SH"), Some("ʃ"))
  assert_eq(@pronouncing.phone_to_ipa("T"), Some("t"))
  assert_eq(@pronouncing.phone_to_ipa("TH"), Some("θ"))
  assert_eq(@pronouncing.phone_to_ipa("V"), Some("v"))
  assert_eq(@pronouncing.phone_to_ipa("W"), Some("w"))
  assert_eq(@pronouncing.phone_to_ipa("Y"), Some("j"))
  assert_eq(@pronouncing.phone_to_ipa("Z"), Some("z"))
  assert_eq(@pronouncing.phone_to_ipa("ZH"), Some("ʒ"))
  assert_eq(@pronouncing.phone_to_ipa("XX"), None)
}

///|
test "arpabet_to_ipa/permit" {
  assert_eq(@pronouncing.arpabet_to_ipa("P ER0 M IH1 T"), "p ɚ m ɪ t")
  assert_eq(@pronouncing.arpabet_to_ipa("P ER1 M IH2 T"), "p ɝ m ɪ t")
}

///|
test "arpabet_to_ipa/unknown token kept" {
  assert_eq(@pronouncing.arpabet_to_ipa("B XX D"), "b XX d")
  assert_eq(@pronouncing.arpabet_to_ipa(""), "")
}

///|
test "phone_edit_distance/identical and stress-insensitive" {
  assert_eq(
    @pronouncing.phone_edit_distance("P ER0 M IH1 T", "P ER0 M IH1 T"),
    0,
  )
  // 重音差异不计入距离
  assert_eq(
    @pronouncing.phone_edit_distance("P ER0 M IH1 T", "P ER1 M IH2 T"),
    0,
  )
  assert_eq(@pronouncing.phone_edit_distance("", ""), 0)
}

///|
test "phone_edit_distance/substitution insertion deletion" {
  // 一个音素替换
  assert_eq(
    @pronouncing.phone_edit_distance("P ER0 M IH1 T", "P ER0 M IH1 S"),
    1,
  )
  // 一个音素插入
  assert_eq(
    @pronouncing.phone_edit_distance("P ER0 M IH1 T", "P ER0 M IH1 T S"),
    1,
  )
  // 一个音素删除
  assert_eq(@pronouncing.phone_edit_distance("P ER0 M IH1 T", "P ER0 M IH1"), 1)
  // 完全不同
  assert_eq(@pronouncing.phone_edit_distance("B", "P ER0 M IH1 T"), 5)
}

///|
test "inventory sizes" {
  assert_eq(@pronouncing.arpabet_vowels.length(), 15)
  assert_eq(@pronouncing.arpabet_consonants.length(), 24)
}
