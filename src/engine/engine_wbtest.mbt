///|
async fn run_cfg(json : String, text : String) -> String raise {
  compile(@config.parse(json)).run(text)
}

///|
fn compile_err(json : String) -> String {
  try {
    compile(@config.parse(json)) |> ignore
    "NO ERROR RAISED"
  } catch {
    @config.ConfigError(m) => m
    e => "OTHER ERROR: \{e}"
  }
}

///|
async test "replace action is wired through the pipeline" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "o", "replacement": "0" } }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "foo"), "f00")
}

///|
async test "matcher gates the hook (no match = unchanged)" {
  let json =
    #|{
    #|  "hooks": [
    #|    {
    #|      "match": { "pattern": "zzz" },
    #|      "action": { "type": "replace", "pattern": "a", "replacement": "X" }
    #|    }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "banana"), "banana")
}

///|
async test "matcher matches = hook applies" {
  let json =
    #|{
    #|  "hooks": [
    #|    {
    #|      "match": { "pattern": "ana" },
    #|      "action": { "type": "replace", "pattern": "a", "replacement": "X" }
    #|    }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "banana"), "bXnXnX")
}

///|
async test "pipeline applies hooks in order" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "a", "replacement": "b" } },
    #|    { "action": { "type": "replace", "pattern": "b", "replacement": "c" } }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "a"), "c")
}

///|
async test "empty hooks leave text unchanged" {
  let json =
    #|{ "hooks": [] }
  @test.assert_eq(run_cfg(json, "anything"), "anything")
}

///|
async test "pipe transforms text through a command's stdout" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "pipe", "run": ["tr", "[:lower:]", "[:upper:]"] } }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "hello"), "HELLO")
}

///|
async test "exec runs a command but leaves the text unchanged" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "exec", "run": ["true"] } }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "untouched"), "untouched")
}

///|
async test "on_error skip keeps the text when the command fails" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "pipe", "run": ["false"], "on_error": "skip" } }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "kept"), "kept")
}

///|
async test "on_error abort propagates the failure" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "pipe", "run": ["false"], "on_error": "abort" } }
    #|  ]
    #|}
  let raised = try {
    run_cfg(json, "x") |> ignore
    false
  } catch {
    _ => true
  }
  @test.assert_eq(raised, true)
}

///|
async test "a slow command is aborted by the timeout" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "pipe", "run": ["sleep", "5"], "timeout_ms": 30, "on_error": "abort" } }
    #|  ]
    #|}
  let msg = try {
    run_cfg(json, "x") |> ignore
    "no error"
  } catch {
    @action.ActionError(m) => m
    e => "other: \{e}"
  }
  @test.assert_eq(msg.contains("timed out"), true)
}

///|
async test "timeout_ms of 0 means no limit" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "pipe", "run": ["cat"], "timeout_ms": 0 } }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "kept"), "kept")
}

///|
async test "abort over a spawn failure still carries the hook index" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "pipe", "run": ["cbhook-no-such-command-xyz"], "on_error": "abort" } }
    #|  ]
    #|}
  let msg = try {
    run_cfg(json, "x") |> ignore
    "no error"
  } catch {
    @action.ActionError(m) => m
    e => "other: \{e}"
  }
  @test.assert_eq(msg.contains("config.hooks[0].action"), true)
}

///|
async test "abort error carries the hook index" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "a", "replacement": "b" } },
    #|    { "action": { "type": "pipe", "run": ["false"], "on_error": "abort" } }
    #|  ]
    #|}
  let msg = try {
    run_cfg(json, "a") |> ignore
    "no error"
  } catch {
    @action.ActionError(m) => m
    e => "other: \{e}"
  }
  @test.assert_eq(msg.contains("config.hooks[1].action"), true)
}

///|
test "replace-only config has no notices" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "a", "replacement": "b" } }
    #|  ]
    #|}
  @test.assert_eq(compile(@config.parse(json)).notices().length(), 0)
}

///|
test "pipe and exec produce no notices" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "pipe", "run": ["a"] } },
    #|    { "action": { "type": "exec", "run": ["b"] } }
    #|  ]
    #|}
  @test.assert_eq(compile(@config.parse(json)).notices().length(), 0)
}

///|
test "start-anchor pattern emits an anchored notice" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "^a", "replacement": "Z" } }
    #|  ]
    #|}
  let compiled = compile(@config.parse(json))
  @test.assert_eq(compiled.notices().length(), 1)
  @test.assert_eq(compiled.notices()[0].contains("anchored pattern"), true)
}

///|
test "end-anchor pattern emits an anchored notice" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "a$", "replacement": "X" } }
    #|  ]
    #|}
  @test.assert_eq(
    compile(@config.parse(json)).notices()[0].contains("anchored pattern"),
    true,
  )
}

///|
test "word-boundary pattern emits an anchored notice" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "\\b", "replacement": "X" } }
    #|  ]
    #|}
  @test.assert_eq(
    compile(@config.parse(json)).notices()[0].contains("anchored pattern"),
    true,
  )
}

///|
test "negated char class is not treated as anchored" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "[^a]", "replacement": "X" } }
    #|  ]
    #|}
  @test.assert_eq(compile(@config.parse(json)).notices().length(), 0)
}

///|
test "escaped anchors are literal; word boundary is not" {
  let lit_caret =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "\\^a", "replacement": "x" } } ] }
  @test.assert_eq(compile(@config.parse(lit_caret)).notices().length(), 0)
  let lit_dollar =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "a\\$", "replacement": "x" } } ] }
  @test.assert_eq(compile(@config.parse(lit_dollar)).notices().length(), 0)
  let boundary =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "\\Bx", "replacement": "y" } } ] }
  @test.assert_eq(compile(@config.parse(boundary)).notices().length(), 1)
}

///|
test "each anchored hook produces its own notice" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "^a", "replacement": "x" } },
    #|    { "action": { "type": "replace", "pattern": "b$", "replacement": "y" } }
    #|  ]
    #|}
  @test.assert_eq(compile(@config.parse(json)).notices().length(), 2)
}

///|
async test "exec on_error skip keeps the text when the command fails" {
  let json =
    #|{ "hooks": [ { "action": { "type": "exec", "run": ["false"], "on_error": "skip" } } ] }
  @test.assert_eq(run_cfg(json, "kept"), "kept")
}

///|
async test "exec on_error abort carries the hook index" {
  let json =
    #|{ "hooks": [ { "action": { "type": "exec", "run": ["false"], "on_error": "abort" } } ] }
  let msg = try {
    run_cfg(json, "x") |> ignore
    "no error"
  } catch {
    @action.ActionError(m) => m
    e => "other: \{e}"
  }
  @test.assert_eq(msg.contains("config.hooks[0].action"), true)
}

///|
async test "a positive timeout that is not exceeded succeeds" {
  let json =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": ["cat"], "timeout_ms": 5000 } } ] }
  @test.assert_eq(run_cfg(json, "kept"), "kept")
}

///|
test "invalid action regex fails compile with path" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "a(b", "replacement": "" } }
    #|  ]
    #|}
  @test.assert_eq(
    compile_err(json).contains(
      "config.hooks[0].action.pattern: invalid regular expression",
    ),
    true,
  )
}

///|
test "invalid matcher regex fails compile with path" {
  let json =
    #|{
    #|  "hooks": [
    #|    {
    #|      "match": { "pattern": "a(b" },
    #|      "action": { "type": "exec", "run": ["x"] }
    #|    }
    #|  ]
    #|}
  @test.assert_eq(
    compile_err(json).contains(
      "config.hooks[0].match.pattern: invalid regular expression",
    ),
    true,
  )
}

///|
test "both invalid matcher and action regex are reported together" {
  let json =
    #|{
    #|  "hooks": [
    #|    {
    #|      "match": { "pattern": "a(" },
    #|      "action": { "type": "replace", "pattern": "b[", "replacement": "" }
    #|    }
    #|  ]
    #|}
  let msg = compile_err(json)
  @test.assert_eq(msg.contains("config.hooks[0].match.pattern"), true)
  @test.assert_eq(msg.contains("config.hooks[0].action.pattern"), true)
}

///|
test "all invalid regexes are reported at once" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "a(", "replacement": "" } },
    #|    { "action": { "type": "replace", "pattern": "b[", "replacement": "" } }
    #|  ]
    #|}
  let msg = compile_err(json)
  @test.assert_eq(msg.contains("config.hooks[0].action.pattern"), true)
  @test.assert_eq(msg.contains("config.hooks[1].action.pattern"), true)
}
