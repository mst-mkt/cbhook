///|
fn is_digit(c : Char) -> Bool {
  c is ('0'..='9')
}

///|
fn digit_val(c : Char) -> Int {
  c.to_int() - '0'.to_int()
}

///|
fn group_str(res : @regexp.MatchResult, i : Int) -> String {
  res.get(i).map(v => v.to_owned()).unwrap_or("")
}

///|
fn all_digits(s : String) -> Bool {
  fn go(v : StringView, seen : Bool) -> Bool {
    match v {
      [] => seen
      [c, .. rest] => if is_digit(c) { go(rest, true) } else { false }
    }
  }

  go(s[:], false)
}

///|
fn parse_digits(s : String) -> Int {
  fn go(v : StringView, acc : Int) -> Int {
    match v {
      [] => acc
      [c, .. rest] => go(rest, acc * 10 + digit_val(c))
    }
  }

  go(s[:], 0)
}

///|
fn take_until(v0 : StringView, delim : Char) -> (String, StringView) {
  fn go(v : StringView, acc : String) -> (String, StringView) {
    match v {
      [] => (acc, v)
      [c, .. rest] =>
        if c == delim {
          (acc, rest)
        } else {
          go(rest, acc + c.to_string())
        }
    }
  }

  go(v0, "")
}

///|
fn lookup(res : @regexp.MatchResult, key : String) -> String {
  if all_digits(key) {
    group_str(res, parse_digits(key))
  } else {
    res.groups().get(key).map(v => v.to_owned()).unwrap_or("")
  }
}

///|
fn expand_into(
  sb : StringBuilder,
  template : String,
  res : @regexp.MatchResult,
) -> Unit {
  fn go(view : StringView) -> Unit {
    match view {
      [] => ()
      ['$', '$', .. rest] => {
        sb.write_char('$')
        go(rest)
      }
      ['$', '{', .. rest] => {
        let (key, after) = take_until(rest, '}')
        sb.write_string(lookup(res, key))
        go(after)
      }
      ['$', '0'..='9' as d, .. rest] => {
        sb.write_string(group_str(res, digit_val(d)))
        go(rest)
      }
      ['$', d, .. rest] => {
        sb.write_char('$')
        sb.write_char(d)
        go(rest)
      }
      ['$'] => sb.write_char('$')
      [c, .. rest] => {
        sb.write_char(c)
        go(rest)
      }
    }
  }

  go(template[:])
}

///|
/// Appends each input segment to a StringBuilder exactly once, keeping the whole
/// replacement linear in the input length (no quadratic `acc + …` rebuilds).
pub fn replace(re : @regexp.Regexp, template : String, text : String) -> String {
  let sb = StringBuilder::new()
  fn go(rem : StringView) -> Unit {
    let res = re.execute(rem)
    if res.matched() {
      let before = res.before()
      let after = res.after()
      let match_len = rem.length() - before.length() - after.length()
      sb.write_view(before)
      expand_into(sb, template, res)
      if match_len == 0 {
        match after {
          [] => ()
          [c, .. rest] => {
            sb.write_char(c)
            go(rest)
          }
        }
      } else {
        go(after)
      }
    } else {
      sb.write_view(rem)
    }
  }

  go(text[:])
  sb.to_string()
}
