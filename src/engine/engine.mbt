///|
pub enum CompiledAction {
  CReplace(@regexp.Regexp, String)
  CPipe(Array[String], Int, @config.OnError)
  CExec(Array[String], Int, @config.OnError)
}

///|
pub struct CompiledHook {
  matcher : @regexp.Regexp?
  action : CompiledAction
}

///|
pub struct Compiled {
  hooks : Array[CompiledHook]
  notice_lines : Array[String]
}

///|
pub fn Compiled::notices(self : Compiled) -> Array[String] {
  self.notice_lines
}

///|
let default_timeout_ms : Int = 5000

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
    Pipe(run~, timeout_ms~, on_error~) =>
      Ok(CPipe(run, default_timeout(timeout_ms), on_error))
    Exec(run~, timeout_ms~, on_error~) =>
      Ok(CExec(run, default_timeout(timeout_ms), on_error))
  }
}

///|
fn default_timeout(timeout_ms : Int?) -> Int {
  timeout_ms.unwrap_or(default_timeout_ms)
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
    Replace(pattern~, ..) =>
      if pattern_is_anchored(pattern) {
        Some(
          "config.hooks[\{i}].action: anchored pattern (^/$/\\b) is only reliable for the first match in global replace",
        )
      } else {
        None
      }
    _ => None
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
    Ok(hooks) => { hooks, notice_lines: collect_notices(config) }
    Err(es) => raise @config.ConfigError(join_nl(es))
  }
}

///|
fn cmd_name(run : Array[String]) -> String {
  match run {
    [c, ..] => c
    [] => "command"
  }
}

///|
fn describe(e : Error) -> String {
  match e {
    @action.ActionError(m) => m
    _ => e.to_string()
  }
}

///|
fn on_failure(
  on_error : @config.OnError,
  ctx : String,
  text : String,
  e : Error,
) -> String raise {
  match on_error {
    @config.Skip => text
    @config.Abort => raise @action.ActionError("\{ctx}: \{describe(e)}")
  }
}

///|
/// Run `body` under the hook's timeout. A timeout of 0 means no limit.
async fn with_limit(
  timeout : Int,
  cmd : String,
  body : async () -> String raise,
) -> String raise {
  if timeout == 0 {
    body()
  } else {
    @async.with_timeout(
      timeout,
      body,
      error=@action.ActionError("\{cmd} timed out after \{timeout}ms"),
    )
  }
}

///|
async fn apply_hook(hook : CompiledHook, text : String, ctx : String) -> String raise {
  let matches = match hook.matcher {
    Some(re) => re.execute(text).matched()
    None => true
  }
  if matches {
    match hook.action {
      CReplace(re, template) => @action.replace(re, template, text)
      CPipe(run, timeout, on_error) =>
        try with_limit(timeout, cmd_name(run), () => @action.run_pipe(run[:], text)) catch {
          e => on_failure(on_error, ctx, text, e)
        }
      CExec(run, timeout, on_error) =>
        try with_limit(timeout, cmd_name(run), () => {
          @action.run_exec(run[:], text)
          text
        }) catch {
          e => on_failure(on_error, ctx, text, e)
        }
    }
  } else {
    text
  }
}

///|
async fn apply_all(
  hooks : ArrayView[CompiledHook],
  text : String,
  i : Int,
) -> String raise {
  match hooks {
    [] => text
    [h, .. rest] =>
      apply_all(rest, apply_hook(h, text, "config.hooks[\{i}].action"), i + 1)
  }
}

///|
pub async fn run(compiled : Compiled, text : String) -> String raise {
  apply_all(compiled.hooks[:], text, 0)
}
