///|
fn run_cfg(json : String, text : String) -> String raise {
  run(compile(@config.parse(json)), text)
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
test "replace action is wired through the pipeline" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "o", "with": "0" } }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "foo"), "f00")
}

///|
test "matcher gates the hook (no match = unchanged)" {
  let json =
    #|{
    #|  "hooks": [
    #|    {
    #|      "match": { "pattern": "zzz" },
    #|      "action": { "type": "replace", "pattern": "a", "with": "X" }
    #|    }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "banana"), "banana")
}

///|
test "matcher matches = hook applies" {
  let json =
    #|{
    #|  "hooks": [
    #|    {
    #|      "match": { "pattern": "ana" },
    #|      "action": { "type": "replace", "pattern": "a", "with": "X" }
    #|    }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "banana"), "bXnXnX")
}

///|
test "pipeline applies hooks in order" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "a", "with": "b" } },
    #|    { "action": { "type": "replace", "pattern": "b", "with": "c" } }
    #|  ]
    #|}
  @test.assert_eq(run_cfg(json, "a"), "c")
}

///|
test "empty hooks leave text unchanged" {
  let json =
    #|{ "hooks": [] }
  @test.assert_eq(run_cfg(json, "anything"), "anything")
}

///|
test "pipe/exec are passthrough with a notice" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "pipe", "run": ["jq"] } }
    #|  ]
    #|}
  let compiled = compile(@config.parse(json))
  @test.assert_eq(run(compiled, "untouched"), "untouched")
  @test.assert_eq(compiled.notices.length(), 1)
  @test.assert_eq(
    compiled.notices[0].contains("pipe is not yet implemented"),
    true,
  )
}

///|
test "replace-only config has no notices" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "a", "with": "b" } }
    #|  ]
    #|}
  @test.assert_eq(compile(@config.parse(json)).notices.length(), 0)
}

///|
test "mixed pipe and exec notices keep order and index" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "pipe", "run": ["a"] } },
    #|    { "action": { "type": "exec", "run": ["b"] } }
    #|  ]
    #|}
  let compiled = compile(@config.parse(json))
  @test.assert_eq(compiled.notices.length(), 2)
  @test.assert_eq(
    compiled.notices[0].contains("config.hooks[0].action: pipe"),
    true,
  )
  @test.assert_eq(
    compiled.notices[1].contains("config.hooks[1].action: exec"),
    true,
  )
}

///|
test "start-anchor pattern emits an anchored notice" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "^a", "with": "Z" } }
    #|  ]
    #|}
  let compiled = compile(@config.parse(json))
  @test.assert_eq(compiled.notices.length(), 1)
  @test.assert_eq(compiled.notices[0].contains("anchored pattern"), true)
}

///|
test "end-anchor pattern emits an anchored notice" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "a$", "with": "X" } }
    #|  ]
    #|}
  @test.assert_eq(
    compile(@config.parse(json)).notices[0].contains("anchored pattern"),
    true,
  )
}

///|
test "word-boundary pattern emits an anchored notice" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "\\b", "with": "X" } }
    #|  ]
    #|}
  @test.assert_eq(
    compile(@config.parse(json)).notices[0].contains("anchored pattern"),
    true,
  )
}

///|
test "negated char class is not treated as anchored" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "[^a]", "with": "X" } }
    #|  ]
    #|}
  @test.assert_eq(compile(@config.parse(json)).notices.length(), 0)
}

///|
test "invalid action regex fails compile with path" {
  let json =
    #|{
    #|  "hooks": [
    #|    { "action": { "type": "replace", "pattern": "a(b", "with": "" } }
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
    #|      "action": { "type": "replace", "pattern": "b[", "with": "" }
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
    #|    { "action": { "type": "replace", "pattern": "a(", "with": "" } },
    #|    { "action": { "type": "replace", "pattern": "b[", "with": "" } }
    #|  ]
    #|}
  let msg = compile_err(json)
  @test.assert_eq(msg.contains("config.hooks[0].action.pattern"), true)
  @test.assert_eq(msg.contains("config.hooks[1].action.pattern"), true)
}
