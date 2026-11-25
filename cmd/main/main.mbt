// pronouncing CLI：查询 CMU 发音词典 / ARPABET 音素分析。
//
// 用法：
// ```bash
// moon run cmd/main -- phones permit
// moon run cmd/main -- rhymes conditioner --json
// moon run cmd/main -- ipa permit
// moon run cmd/main -- search "ER1 P AH0" --json
// moon run cmd/main -- --batch --json phones cat dog bird
// ```
//
// `--batch` 把每个位置参数都当作一次查询，逐行输出 JSON（JSON Lines），
// 供 tools/diff_test.mjs / tools/diff_test.py 差分对拍消费。

///|
fn main {
  run(cli_args()) catch {
    InvalidArguments(message) => {
      eprintln("error: \{message}")
      panic()
    }
  }
}

///|
#cfg(target="js")
fn cli_args() -> Array[String] {
  // Node 会同时给出可执行文件与脚本路径；其它后端只给一个。
  @env.args()[1:].to_owned()
}

///|
#cfg(not(target="js"))
fn cli_args() -> Array[String] {
  @env.args()
}

///|
suberror CliError {
  InvalidArguments(String)
}

///|
/// 解析后的命令行选项。第一个位置参数是子命令，其余是查询参数。
struct CliOptions {
  command : String
  args : Array[String]
  json : Bool
  batch : Bool
  help : Bool
}

///|
fn parse_options(args : Array[String]) -> CliOptions raise CliError {
  let positionals : Array[String] = []
  let mut json_mode = false
  let mut batch_mode = false
  let mut help = false
  let mut options_done = false
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if options_done {
      positionals.push(arg)
      i += 1
      continue
    }
    match arg {
      "--" => {
        options_done = true
        i += 1
      }
      "--help" => {
        help = true
        i += 1
      }
      "--json" => {
        json_mode = true
        i += 1
      }
      "--batch" => {
        batch_mode = true
        i += 1
      }
      _ => {
        if arg.has_prefix("--") {
          raise InvalidArguments("unknown option: \{arg}; use --help")
        }
        positionals.push(arg)
        i += 1
      }
    }
  }
  if help {
    return { command: "", args: [], json: json_mode, batch: batch_mode, help, }
  }
  if positionals.is_empty() {
    raise InvalidArguments("a command is required; use --help for usage")
  }
  let command = positionals[0]
  match command {
    "phones"
    | "rhymes"
    | "syllables"
    | "stress"
    | "search"
    | "stresses"
    | "ipa"
    | "info" => ()
    _ => raise InvalidArguments("unknown command: \{command}; use --help")
  }
  let rest = positionals[1:].to_owned()
  if batch_mode {
    if rest.is_empty() {
      raise InvalidArguments("--batch requires at least one argument")
    }
  } else if rest.length() != 1 {
    raise InvalidArguments("exactly one argument is required (or use --batch)")
  }
  { command, args: rest, json: json_mode, batch: batch_mode, help, }
}

///|
fn run(args : Array[String]) -> Unit raise CliError {
  let opts = parse_options(args)
  if opts.help {
    println(
      "usage: moon run cmd/main -- <command> <arg>... [--json] [--batch]\ncommands:\n  phones <word>     ARPABET pronunciation(s)\n  rhymes <word>     words that rhyme (sorted, unique)\n  syllables <word>  syllable count per pronunciation\n  stress <word>     stress pattern per pronunciation\n  search <regex>    words whose pronunciation matches regex\n  stresses <regex>  words whose stress pattern matches regex\n  ipa <word>        IPA transcription per pronunciation\n  info <word>       phones + stress + syllables + rhyming part + IPA",
    )
  } else if opts.batch {
    for arg in opts.args {
      println(result_json(opts.command, arg))
    }
  } else if opts.json {
    println(result_json(opts.command, opts.args[0]))
  } else {
    print_human(opts.command, opts.args[0])
  }
}

///|
/// search 的受检错误转成 CLI 错误。
fn search_words(pattern : String) -> Array[String] raise CliError {
  @lib.search(pattern) catch {
    @lib.PronouncingError::InvalidRegex(msg) =>
      raise InvalidArguments("invalid regex: \{msg}")
  }
}

///|
fn stress_words(pattern : String) -> Array[String] raise CliError {
  @lib.search_stresses(pattern) catch {
    @lib.PronouncingError::InvalidRegex(msg) =>
      raise InvalidArguments("invalid regex: \{msg}")
  }
}

///|
/// 单次查询的 JSON 对象字符串。字段顺序固定，供差分对拍逐字消费。
fn result_json(command : String, arg : String) -> String raise CliError {
  match command {
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
    "search" => {
      let ws = search_words(arg)
      "{\"op\":\"search\",\"pattern\":\{json_string(arg)},\"words\":\{json_array(ws)}}"
    }
    "stresses" => {
      let ws = stress_words(arg)
      "{\"op\":\"stresses\",\"pattern\":\{json_string(arg)},\"words\":\{json_array(ws)}}"
    }
    "ipa" => {
      let ipas = @lib.phones_for_word(arg).map(p => @lib.arpabet_to_ipa(p))
      "{\"op\":\"ipa\",\"word\":\{json_string(arg)},\"ipa\":\{json_array(ipas)}}"
    }
    "info" => {
      let ps = @lib.phones_for_word(arg)
      let ss = ps.map(p => @lib.stresses(p))
      let syl = ps.map(p => @lib.syllable_count(p))
      let rp = ps.map(p => @lib.rhyming_part(p))
      let ipas = ps.map(p => @lib.arpabet_to_ipa(p))
      "{\"op\":\"info\",\"word\":\{json_string(arg)},\"phones\":\{json_array(ps)},\"stresses\":\{json_array(ss)},\"syllables\":\{json_int_array(syl)},\"rhyming_parts\":\{json_array(rp)},\"ipa\":\{json_array(ipas)}}"
    }
    _ => raise InvalidArguments("unknown command: \{command}")
  }
}

///|
fn print_human(command : String, arg : String) -> Unit raise CliError {
  match command {
    "phones" => {
      let ps = @lib.phones_for_word(arg)
      if ps.is_empty() {
        println("(not in dictionary)")
      }
      for p in ps {
        println(p)
      }
    }
    "rhymes" =>
      for w in @lib.rhymes(arg) {
        println(w)
      }
    "syllables" =>
      for p in @lib.phones_for_word(arg) {
        println("\{@lib.syllable_count(p)}\t\{p}")
      }
    "stress" =>
      for s in @lib.stresses_for_word(arg) {
        println(s)
      }
    "search" =>
      for w in search_words(arg) {
        println(w)
      }
    "stresses" =>
      for w in stress_words(arg) {
        println(w)
      }
    "ipa" =>
      for p in @lib.phones_for_word(arg) {
        println("\{@lib.arpabet_to_ipa(p)}\t\{p}")
      }
    "info" => {
      let ps = @lib.phones_for_word(arg)
      if ps.is_empty() {
        println("(not in dictionary)")
      }
      for p in ps {
        println("phones       : \{p}")
        println("stress       : \{@lib.stresses(p)}")
        println("syllables    : \{@lib.syllable_count(p)}")
        println("rhyming part : \{@lib.rhyming_part(p)}")
        println("ipa          : \{@lib.arpabet_to_ipa(p)}")
        println("")
      }
    }
    _ => raise InvalidArguments("unknown command: \{command}")
  }
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
/// 按 RFC 8259 转义字符串内容，含首尾引号（逐字符遍历，补齐控制字符）。
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
