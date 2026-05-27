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
fn try_compile(
  pattern : String,
  flags : String?,
  ctx : String,
) -> Result[@regexp.Regexp, Array[String]] {
  Ok(compile_re(pattern, flags)) catch {
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
      try_compile(pattern, flags, ctx + ".pattern").map(re => {
        CReplace(re, replacement)
      })
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
  let matcher_result : Result[@regexp.Regexp?, Array[String]] = match
    hook.matcher {
    Some(m) =>
      try_compile(m.pattern, m.flags, ctx + ".match.pattern").map(re => Some(re))
    None => Ok(None)
  }
  let action_result = compile_action(hook.action, ctx + ".action")
  match (matcher_result, action_result) {
    (Ok(matcher), Ok(action)) => Ok({ matcher, action })
    _ =>
      Err(
        @config.combine([
          @config.errs(matcher_result),
          @config.errs(action_result),
        ]),
      )
  }
}

// Heuristic: regexp global-replace is unreliable past the first match for
// anchors (`^` `$` `\b` `\B`), so detect them to warn.

///|
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
  .mapi((i, h) => {
    match h.action {
      Replace(pattern~, ..) =>
        if pattern_is_anchored(pattern) {
          Some(
            "config.hooks[\{i}].action: anchored pattern (^/$/\\b) is only reliable for the first match in global replace",
          )
        } else {
          None
        }
      _ => None
    }
  })
  .filter_map(o => o)
}

///|
pub fn compile(config : @config.Config) -> Compiled raise @config.ConfigError {
  let results = config.hooks.mapi((i, h) => {
    compile_hook(h, "config.hooks[\{i}]")
  })
  match @config.sequence(results) {
    Ok(hooks) => { hooks, notice_lines: collect_notices(config) }
    Err(es) => raise @config.ConfigError(@config.join_with(es, "\n"))
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

// A timeout of 0 means no limit.

///|
async fn with_limit(
  timeout : Int,
  cmd : String,
  body : async () -> String,
) -> String {
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
async fn apply_hook(hook : CompiledHook, text : String, ctx : String) -> String {
  let matches = match hook.matcher {
    Some(re) => re.execute(text).matched()
    None => true
  }
  guard matches else { return text }
  match hook.action {
    CReplace(re, template) => @action.replace(re, template, text)
    CPipe(run, timeout, on_error) =>
      with_limit(timeout, cmd_name(run), () => @action.run_pipe(run[:], text)) catch {
        e => on_failure(on_error, ctx, text, e)
      }
    CExec(run, timeout, on_error) =>
      with_limit(timeout, cmd_name(run), () => {
        @action.run_exec(run[:], text)
        text
      }) catch {
        e => on_failure(on_error, ctx, text, e)
      }
  }
}

///|
async fn apply_all(
  hooks : ArrayView[CompiledHook],
  text : String,
  i : Int,
) -> String {
  match hooks {
    [] => text
    [h, .. rest] =>
      apply_all(rest, apply_hook(h, text, "config.hooks[\{i}].action"), i + 1)
  }
}

///|
pub async fn Compiled::run(self : Compiled, text : String) -> String {
  apply_all(self.hooks[:], text, 0)
}
