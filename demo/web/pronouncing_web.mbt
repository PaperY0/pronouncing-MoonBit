// 浏览器侧唯一入口：foreign_library + link.js.format = esm 产出带 export 的 ES module。
// 值编组只对简单类型有效（String ↔ JS string），结构体无编组，故返回 JSON 字符串。
// 与 cmd/main 的 result_json 字段对齐；非法正则不 panic，返回 {"error": ...}。

///|
#export_name("pronouncingReport")
pub fn report(op : String, arg : String) -> String {
  match op {
    "phones" => {
      let ps = @lib.phones_for_word(arg)
      "{\"op\":\"phones\",\"word\":\{json_string(arg)},\"phones\":\{json_array(ps)}}"
    }
    "rhymes" => {
      let rs = @lib.rhymes(arg)
      "{\"op\":\"rhymes\",\"word\":\{json_string(arg)},\"rhymes\":\{json_array(rs)}}"
    }
    "syllables" => {
      let counts = @lib.phones_for_word(arg).map(p => @lib.syllable_count(p))
      "{\"op\":\"syllables\",\"word\":\{json_string(arg)},\"syllables\":\{json_int_array(counts)}}"
    }
    "stress" => {
      let ss = @lib.stresses_for_word(arg)
      "{\"op\":\"stress\",\"word\":\{json_string(arg)},\"stresses\":\{json_array(ss)}}"
    }
    "ipa" => {
      let ipas = @lib.phones_for_word(arg).map(p => @lib.arpabet_to_ipa(p))
      "{\"op\":\"ipa\",\"word\":\{json_string(arg)},\"ipa\":\{json_array(ipas)}}"
    }
    "search" => {
      let ws = @lib.search(arg) catch {
        @lib.PronouncingError::InvalidRegex(msg) => return error_json(op, msg)
      }
      "{\"op\":\"search\",\"pattern\":\{json_string(arg)},\"words\":\{json_array(ws)}}"
    }
    "stresses" => {
      let ws = @lib.search_stresses(arg) catch {
        @lib.PronouncingError::InvalidRegex(msg) => return error_json(op, msg)
      }
      "{\"op\":\"stresses\",\"pattern\":\{json_string(arg)},\"words\":\{json_array(ws)}}"
    }
    "info" => {
      let ps = @lib.phones_for_word(arg)
      let ss = ps.map(p => @lib.stresses(p))
      let syl = ps.map(p => @lib.syllable_count(p))
      let rp = ps.map(p => @lib.rhyming_part(p))
      let ipas = ps.map(p => @lib.arpabet_to_ipa(p))
      "{\"op\":\"info\",\"word\":\{json_string(arg)},\"phones\":\{json_array(ps)},\"stresses\":\{json_array(ss)},\"syllables\":\{json_int_array(syl)},\"rhyming_parts\":\{json_array(rp)},\"ipa\":\{json_array(ipas)}}"
    }
    _ => error_json(op, "unknown op")
  }
}

///|
fn error_json(op : String, msg : String) -> String {
  "{\"op\":\{json_string(op)},\"error\":\{json_string(msg)}}"
}

///|
fn json_array(items : Array[String]) -> String {
  "[" + items.map(json_string).join(",") + "]"
}

///|
fn json_int_array(items : Array[Int32]) -> String {
  "[" + items.map(n => "\{n}").join(",") + "]"
}

///|
fn json_string(s : String) -> String {
  let b = StringBuilder()
  b.write_char('"')
  for c in s {
    match c {
      '"' => {
        b.write_char('\\')
        b.write_char('"')
      }
      '\\' => {
        b.write_char('\\')
        b.write_char('\\')
      }
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
      }
      '\r' => {
        b.write_char('\\')
        b.write_char('r')
      }
      '\t' => {
        b.write_char('\\')
        b.write_char('t')
      }
      _ => {
        let n = c.to_int()
        if n < 0x20 {
          b.write_string("\\u00")
          b.write_char(hex_digit(n / 16))
          b.write_char(hex_digit(n % 16))
        } else {
          b.write_char(c)
        }
      }
    }
  }
  b.write_char('"')
  b.to_string()
}

///|
fn hex_digit(n : Int32) -> Char {
  if n < 10 {
    ('0'.to_int() + n).to_char().unwrap()
  } else {
    ('a'.to_int() + n - 10).to_char().unwrap()
  }
}
