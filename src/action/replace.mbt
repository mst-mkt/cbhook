///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn digit_val(c : Char) -> Int {
  c.to_int() - '0'.to_int()
}

///|
fn group_str(res : @regexp.MatchResult, i : Int) -> String {
  match res.get(i) {
    Some(v) => v.to_owned()
    None => ""
  }
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
    match res.groups().get(key) {
      Some(v) => v.to_owned()
      None => ""
    }
  }
}

///|
fn expand(template : String, res : @regexp.MatchResult) -> String {
  fn go(view : StringView, acc : String) -> String {
    match view {
      [] => acc
      ['$', '$', .. rest] => go(rest, acc + "$")
      ['$', '{', .. rest] => {
        let (key, after) = take_until(rest, '}')
        go(after, acc + lookup(res, key))
      }
      ['$', d, .. rest] =>
        if is_digit(d) {
          go(rest, acc + group_str(res, digit_val(d)))
        } else {
          go(rest, acc + "$" + d.to_string())
        }
      ['$'] => acc + "$"
      [c, .. rest] => go(rest, acc + c.to_string())
    }
  }

  go(template[:], "")
}

///|
pub fn replace(re : @regexp.Regexp, template : String, text : String) -> String {
  fn go(rem : StringView, acc : String) -> String {
    let res = re.execute(rem)
    if res.matched() {
      let before = res.before()
      let after = res.after()
      let match_len = rem.length() - before.length() - after.length()
      let acc2 = acc + before.to_owned() + expand(template, res)
      if match_len == 0 {
        match after {
          [] => acc2
          [c, .. rest] => go(rest, acc2 + c.to_string())
        }
      } else {
        go(after, acc2)
      }
    } else {
      acc + rem.to_owned()
    }
  }

  go(text[:], "")
}
