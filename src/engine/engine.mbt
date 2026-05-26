///|
pub(all) enum CompiledAction {
  CReplace(@regexp.Regexp, String)
  CPassthrough(String)
}

///|
pub(all) struct CompiledHook {
  matcher : @regexp.Regexp?
  action : CompiledAction
}

///|
pub(all) struct Compiled {
  hooks : Array[CompiledHook]
  notices : Array[String]
}

///|
fn compile_re(pattern : String, flags : String?) -> @regexp.Regexp raise {
  match flags {
    Some(f) => @regexp.compile(pattern, flags=f)
    None => @regexp.compile(pattern)
  }
}

///|
fn[T] errs(r : Result[T, Array[String]]) -> Array[String] {
  match r {
    Ok(_) => []
    Err(e) => e
  }
}

///|
fn combine(parts : Array[Array[String]]) -> Array[String] {
  parts.fold(init=[], fn(acc, p) { [..acc, ..p] })
}

///|
fn[T] sequence(
  rs : Array[Result[T, Array[String]]],
) -> Result[Array[T], Array[String]] {
  rs.fold(init=Ok([]), fn(acc, r) {
    match (acc, r) {
      (Ok(xs), Ok(x)) => Ok([..xs, x])
      _ => Err(combine([errs(acc), errs(r)]))
    }
  })
}

///|
fn join_nl(items : Array[String]) -> String {
  match items {
    [] => ""
    [head, .. tail] => tail.fold(init=head, fn(acc, x) { acc + "\n" + x })
  }
}

///|
fn try_compile(
  pattern : String,
  flags : String?,
  ctx : String,
) -> Result[@regexp.Regexp, Array[String]] {
  try Ok(compile_re(pattern, flags)) catch {
    e => Err(["\{ctx}: invalid regular expression: \{e}"])
  }
}

///|
fn compile_action(
  action : @config.Action,
  ctx : String,
) -> Result[CompiledAction, Array[String]] {
  match action {
    Replace(pattern~, replacement~, flags~) =>
      match try_compile(pattern, flags, ctx + ".pattern") {
        Ok(re) => Ok(CReplace(re, replacement))
        Err(e) => Err(e)
      }
    Pipe(..) => Ok(CPassthrough("pipe"))
    Exec(..) => Ok(CPassthrough("exec"))
  }
}

///|
fn compile_hook(
  hook : @config.Hook,
  ctx : String,
) -> Result[CompiledHook, Array[String]] {
  let matcher_result : Result[@regexp.Regexp?, Array[String]] = match hook.matcher {
    Some(m) =>
      match try_compile(m.pattern, m.flags, ctx + ".match.pattern") {
        Ok(re) => Ok(Some(re))
        Err(e) => Err(e)
      }
    None => Ok(None)
  }
  let action_result = compile_action(hook.action, ctx + ".action")
  match (matcher_result, action_result) {
    (Ok(matcher), Ok(action)) => Ok({ matcher, action })
    _ => Err(combine([errs(matcher_result), errs(action_result)]))
  }
}

///|
/// Heuristic: does the pattern use a position assertion (`^` `$` `\b` `\B`)
/// whose global-replace behaviour is unreliable past the first match?
fn pattern_is_anchored(pattern : String) -> Bool {
  fn go(v : StringView, prev : Char) -> Bool {
    match v {
      [] => false
      [c, .. rest] =>
        if (c == 'b' || c == 'B') && prev == '\\' {
          true
        } else if c == '^' && prev != '\\' && prev != '[' {
          true
        } else if c == '$' && prev != '\\' {
          true
        } else {
          go(rest, c)
        }
    }
  }

  go(pattern[:], ' ')
}

///|
fn collect_notices(config : @config.Config) -> Array[String] {
  config.hooks
  .mapi((i, h) => match h.action {
    Pipe(..) =>
      Some("config.hooks[\{i}].action: pipe is not yet implemented (passthrough)")
    Exec(..) =>
      Some("config.hooks[\{i}].action: exec is not yet implemented (passthrough)")
    Replace(pattern~, ..) =>
      if pattern_is_anchored(pattern) {
        Some(
          "config.hooks[\{i}].action: anchored pattern (^/$/\\b) is only reliable for the first match in global replace",
        )
      } else {
        None
      }
  })
  .fold(init=[], fn(acc, o) {
    match o {
      Some(s) => [..acc, s]
      None => acc
    }
  })
}

///|
pub fn compile(config : @config.Config) -> Compiled raise @config.ConfigError {
  let results = config.hooks.mapi((i, h) =>
    compile_hook(h, "config.hooks[\{i}]"))
  match sequence(results) {
    Ok(hooks) => { hooks, notices: collect_notices(config) }
    Err(es) => raise @config.ConfigError(join_nl(es))
  }
}

///|
fn apply_hook(hook : CompiledHook, text : String) -> String {
  let matches = match hook.matcher {
    Some(re) => re.execute(text).matched()
    None => true
  }
  if matches {
    match hook.action {
      CReplace(re, template) => @action.replace(re, template, text)
      CPassthrough(_) => text
    }
  } else {
    text
  }
}

///|
pub fn run(compiled : Compiled, text : String) -> String {
  compiled.hooks.fold(init=text, fn(acc, h) { apply_hook(h, acc) })
}
