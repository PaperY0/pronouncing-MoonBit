// White-box tests：内部辅助函数（split_entry / phone_tokens / 词边界 / join / 排序去重）。

///|
test "split_entry/basic" {
  assert_eq(split_entry("permit P ER0 M IH1 T"), ("permit", "P ER0 M IH1 T"))
  assert_eq(split_entry("word"), ("word", ""))
  assert_eq(split_entry("a B"), ("a", "B"))
}

///|
test "phone_tokens/splits and filters empty" {
  assert_eq(phone_tokens("P ER0 M IH1 T"), ["P", "ER0", "M", "IH1", "T"])
  assert_eq(phone_tokens(""), [])
  assert_eq(phone_tokens("   "), [])
  assert_eq(phone_tokens("B"), ["B"])
}

///|
test "is_word_char" {
  assert_true(is_word_char('A'))
  assert_true(is_word_char('z'))
  assert_true(is_word_char('0'))
  assert_true(is_word_char('_'))
  assert_true(is_word_char(' ') == false)
  assert_true(is_word_char('-') == false)
}

///|
test "is_word_boundary/transitions" {
  let chars = "P ER1".to_array()
  assert_true(is_word_boundary(chars, 0)) // 串首 → P
  assert_true(is_word_boundary(chars, 1)) // P → 空格
  assert_true(is_word_boundary(chars, 2)) // 空格 → E
  assert_true(is_word_boundary(chars, 3) == false) // E → R（词内部）
  assert_true(is_word_boundary(chars, 5)) // 串尾
}

///|
test "join_str" {
  assert_eq(join_str(["a", "b", "c"], " "), "a b c")
  assert_eq(join_str([], " "), "")
  assert_eq(join_str(["a"], " "), "a")
  assert_eq(join_str(["a", "b"], "-"), "a-b")
}

///|
test "sorted_unique/sorts and dedupes" {
  assert_eq(sorted_unique(["b", "a", "b", "c", "a"]), ["a", "b", "c"])
  assert_eq(sorted_unique([]), [])
  assert_eq(sorted_unique(["x"]), ["x"])
}

///|
test "sorted_unique/lexicographic not length" {
  assert_eq(sorted_unique(["b", "aa"]), ["aa", "b"])
  assert_eq(
    sorted_unique(["petitioner", "parishioner", "commissioner", "practitioner"]),
    ["commissioner", "parishioner", "petitioner", "practitioner"],
  )
}
