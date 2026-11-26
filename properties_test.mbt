// Black-box tests：跨 API 的行为性质与边界语义。
// 与 cmudict_test / arpabet_test 的逐点断言互补：这里验证不变量
//（度量性质、inventory 自洽、词边界语义、返回副本隔离、押韵部 fallback）。

///|
test "phone_edit_distance/metric properties on real words" {
  let words = [
    "permit", "python", "orange", "banana", "computer", "water", "hello", "world",
  ]
  let phones : Array[String] = []
  for w in words {
    phones.push(@pronouncing.phones_for_word(w)[0])
  }
  for p in phones {
    // 同一性
    assert_eq(@pronouncing.phone_edit_distance(p, p), 0)
    // 到空串的距离 = 音素个数
    let mut n = 0
    for tok in p.split(" ") {
      if tok.length() > 0 {
        n += 1
      }
    }
    assert_eq(@pronouncing.phone_edit_distance(p, ""), n)
    assert_eq(@pronouncing.phone_edit_distance("", p), n)
    for q in phones {
      // 对称性
      let dpq = @pronouncing.phone_edit_distance(p, q)
      assert_eq(dpq, @pronouncing.phone_edit_distance(q, p))
      // 非负
      assert_true(dpq >= 0)
      for r in phones {
        // 三角不等式
        assert_true(
          @pronouncing.phone_edit_distance(p, r) <=
          dpq + @pronouncing.phone_edit_distance(q, r),
        )
      }
    }
  }
}

///|
test "inventory/is internally consistent" {
  // 每个元音：is_vowel、分类 Vowel、有 IPA 映射
  for v in @pronouncing.arpabet_vowels {
    assert_true(@pronouncing.is_vowel(v))
    assert_eq(@pronouncing.phone_kind(v), Some(@pronouncing.PhoneKind::Vowel))
    assert_true(@pronouncing.phone_to_ipa(v) is Some(_))
    // 带重音数字后判断不变
    assert_true(@pronouncing.is_vowel(v + "1"))
    assert_eq(
      @pronouncing.phone_kind(v + "2"),
      Some(@pronouncing.PhoneKind::Vowel),
    )
  }
  // 每个辅音：非元音、分类存在且不是 Vowel、有 IPA 映射
  for c in @pronouncing.arpabet_consonants {
    assert_true(@pronouncing.is_vowel(c) == false)
    let kind = @pronouncing.phone_kind(c)
    assert_true(kind is Some(_))
    assert_true(kind != Some(@pronouncing.PhoneKind::Vowel))
    assert_true(@pronouncing.phone_to_ipa(c) is Some(_))
  }
  // 两个 inventory 无交集、各自无重复
  let nv = @pronouncing.arpabet_vowels.length()
  let nc = @pronouncing.arpabet_consonants.length()
  for i in 0..<nv {
    let mut j = i + 1
    while j < nv {
      assert_true(
        @pronouncing.arpabet_vowels[i] != @pronouncing.arpabet_vowels[j],
      )
      j += 1
    }
    for c in @pronouncing.arpabet_consonants {
      assert_true(@pronouncing.arpabet_vowels[i] != c)
    }
  }
  for i in 0..<nc {
    let mut j = i + 1
    while j < nc {
      assert_true(
        @pronouncing.arpabet_consonants[i] != @pronouncing.arpabet_consonants[j],
      )
      j += 1
    }
  }
}

///|
test "search/word boundary is per phone token" {
  // "sing" = S IH1 NG：\bN\b 不得命中 NG 里的 N，\bNG\b 必须命中
  let n_words = @pronouncing.search("N") catch { _ => [] }
  assert_true(n_words.iter().any(w => w == "noon"))
  assert_true(n_words.iter().any(w => w == "sing") == false)
  let ng_words = @pronouncing.search("NG") catch { _ => [] }
  assert_true(ng_words.iter().any(w => w == "sing"))
  // 多 token 模式同样按词边界匹配
  let m_ih = @pronouncing.search("M IH1") catch { _ => [] }
  assert_true(m_ih.iter().any(w => w == "permit"))
}

///|
test "search_stresses/anchors match whole pattern" {
  // apple = AE1 P AH0 → "10"；^10$ 只命中恰好两音节、重音 10 的词
  let w = @pronouncing.search_stresses("^10$") catch { _ => [] }
  assert_true(w.iter().any(x => x == "apple"))
  assert_true(w.iter().any(x => x == "gubernatorial") == false)
  assert_true(w.iter().any(x => x == "literally") == false)
}

///|
test "phones_for_word/returns isolated copy" {
  let a = @pronouncing.phones_for_word("permit")
  assert_eq(a.length(), 2)
  a.push("X Y Z")
  a[0] = "mutated"
  let b = @pronouncing.phones_for_word("permit")
  assert_eq(b, ["P ER0 M IH1 T", "P ER1 M IH2 T"])
}

///|
test "rhyming_part/fallback and index-zero stress" {
  // 单 token：循环不含 index 0，fallback 返回原串
  assert_eq(@pronouncing.rhyming_part("AO1"), "AO1")
  assert_eq(@pronouncing.rhyming_part("AH0"), "AH0")
  assert_eq(@pronouncing.rhyming_part(""), "")
  // 重读元音只在 index 0（awesome = AO1 S AH0 M）：fallback 返回整串
  assert_eq(@pronouncing.rhyming_part("AO1 S AH0 M"), "AO1 S AH0 M")
  // 末尾重读元音在中间（macaw = M AH0 K AO1）
  assert_eq(@pronouncing.rhyming_part("M AH0 K AO1"), "AO1")
  // 次重音 2 同样触发（seesaw = S IY1 S AO2）
  assert_eq(@pronouncing.rhyming_part("S IY1 S AO2"), "AO2")
}
