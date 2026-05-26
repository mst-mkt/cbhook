///|
fn decode_err(src : String) -> String {
  try {
    parse(src) |> ignore
    "NO ERROR RAISED"
  } catch {
    ConfigError(m) => m
    e => "OTHER ERROR: \{e}"
  }
}

///|
fn get_key(json : Json, key : String) -> Json {
  guard json is Object(m) else { abort("get_key: \{key}: not an object") }
  guard m.get(key) is Some(v) else { abort("get_key: missing key \{key}") }
  v
}

///|
fn assert_json(actual : Json, expected : Json) -> Unit raise {
  @test.assert_eq(actual.stringify(), expected.stringify())
}

///|
test "minimal replace hook decodes to the expected Config" {
  let src =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "a", "with": "b" } } ] }
  @test.assert_eq(
    parse(src),
    Config::{
      hooks: [
        Hook::{
          name: None,
          matcher: None,
          action: Replace(pattern="a", replacement="b", flags=None),
        },
      ],
      log_level: None,
    },
  )
}

///|
test "log_level decodes when present and rejects unknown values" {
  let ok =
    #|{ "hooks": [], "log_level": "debug" }
  @test.assert_eq(parse(ok).log_level, Some(Debug))
  let absent =
    #|{ "hooks": [] }
  @test.assert_eq(parse(absent).log_level, None)
  let bad =
    #|{ "hooks": [], "log_level": "loud" }
  @test.assert_eq(decode_err(bad).contains("config.log_level"), true)
}

///|
test "replace with flags and a named hook + matcher" {
  let src =
    #|{ "hooks": [
    #|  { "name": "trim", "match": { "pattern": "x+$", "flags": "m" },
    #|    "action": { "type": "replace", "pattern": "x+$", "with": "", "flags": "gm" } }
    #|] }
  let cfg = parse(src)
  @test.assert_eq(cfg.hooks[0].name, Some("trim"))
  @test.assert_eq(
    cfg.hooks[0].matcher,
    Some(Matcher::{ pattern: "x+$", flags: Some("m") }),
  )
  @test.assert_eq(
    cfg.hooks[0].action,
    Replace(pattern="x+$", replacement="", flags=Some("gm")),
  )
}

///|
test "pipe with all fields" {
  let src =
    #|{ "hooks": [ { "action":
    #|  { "type": "pipe", "run": ["jq", "."], "timeout_ms": 2000, "on_error": "abort" } } ] }
  let cfg = parse(src)
  @test.assert_eq(
    cfg.hooks[0].action,
    Pipe(run=["jq", "."], timeout_ms=Some(2000), on_error=Abort),
  )
}

///|
test "pipe defaults: no timeout_ms -> None, no on_error -> Skip" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": ["cat"] } } ] }
  let cfg = parse(src)
  @test.assert_eq(
    cfg.hooks[0].action,
    Pipe(run=["cat"], timeout_ms=None, on_error=Skip),
  )
}

///|
test "exec with skip on_error" {
  let src =
    #|{ "hooks": [ { "action":
    #|  { "type": "exec", "run": ["notify-send", "copied"], "on_error": "skip" } } ] }
  let cfg = parse(src)
  @test.assert_eq(
    cfg.hooks[0].action,
    Exec(run=["notify-send", "copied"], timeout_ms=None, on_error=Skip),
  )
}

///|
test "empty hooks array is valid" {
  let src =
    #|{ "hooks": [] }
  let cfg = parse(src)
  @test.assert_eq(cfg.hooks.length(), 0)
}

///|
test "multiple hooks preserve order" {
  let src =
    #|{ "hooks": [
    #|  { "action": { "type": "replace", "pattern": "a", "with": "b" } },
    #|  { "action": { "type": "pipe", "run": ["jq"] } },
    #|  { "action": { "type": "exec", "run": ["true"] } }
    #|] }
  let cfg = parse(src)
  @test.assert_eq(cfg.hooks.length(), 3)
  @test.assert_eq(
    cfg.hooks[1].action,
    Pipe(run=["jq"], timeout_ms=None, on_error=Skip),
  )
  @test.assert_eq(
    cfg.hooks[2].action,
    Exec(run=["true"], timeout_ms=None, on_error=Skip),
  )
}

///|
test "top-level must be an object" {
  @test.assert_eq(decode_err("[]"), "config: expected an object")
}

///|
test "missing hooks field" {
  @test.assert_eq(decode_err("{}"), "config: missing required field \"hooks\"")
}

///|
test "hooks must be an array" {
  let src =
    #|{ "hooks": 1 }
  @test.assert_eq(decode_err(src), "config.hooks: expected an array")
}

///|
test "hook must be an object" {
  let src =
    #|{ "hooks": [1] }
  @test.assert_eq(decode_err(src), "config.hooks[0]: expected an object")
}

///|
test "hook missing action" {
  let src =
    #|{ "hooks": [ { "name": "x" } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0]: missing required field \"action\"",
  )
}

///|
test "hook with unknown field" {
  let src =
    #|{ "hooks": [ { "action": { "type": "exec", "run": ["x"] }, "foo": 1 } ] }
  @test.assert_eq(decode_err(src), "config.hooks[0]: unknown field \"foo\"")
}

///|
test "action missing type tag" {
  let src =
    #|{ "hooks": [ { "action": {} } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action: missing required field \"type\"",
  )
}

///|
test "action type must be a string" {
  let src =
    #|{ "hooks": [ { "action": { "type": 1 } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.type: expected a string",
  )
}

///|
test "unknown action type lists the valid ones" {
  let src =
    #|{ "hooks": [ { "action": { "type": "frobnicate" } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.type: unknown value \"frobnicate\" (expected one of replace, pipe, exec)",
  )
}

///|
test "replace missing pattern" {
  let src =
    #|{ "hooks": [ { "action": { "type": "replace", "with": "" } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action: missing required field \"pattern\"",
  )
}

///|
test "replace missing with" {
  let src =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "a" } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action: missing required field \"with\"",
  )
}

///|
test "replace pattern must be a string" {
  let src =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": 1, "with": "" } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.pattern: expected a string",
  )
}

///|
test "replace with unknown field" {
  let src =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "a", "with": "b", "g": true } } ] }
  @test.assert_eq(decode_err(src), "config.hooks[0].action: unknown field \"g\"")
}

///|
test "pipe missing run" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe" } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action: missing required field \"run\"",
  )
}

///|
test "pipe run must be a non-empty array" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": [] } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.run: expected at least 1 item(s)",
  )
}

///|
test "pipe run elements must be strings" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": ["ok", 2] } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.run[1]: expected a string",
  )
}

///|
test "pipe timeout_ms must be a number" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": ["x"], "timeout_ms": "soon" } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.timeout_ms: expected a number",
  )
}

///|
test "pipe timeout_ms must be an integer" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": ["x"], "timeout_ms": 1.5 } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.timeout_ms: expected an integer",
  )
}

///|
test "pipe timeout_ms must be non-negative" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": ["x"], "timeout_ms": -1 } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.timeout_ms: expected >= 0",
  )
}

///|
test "on_error must be skip or abort" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": ["x"], "on_error": "nope" } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.on_error: expected one of skip, abort, got \"nope\"",
  )
}

///|
test "matcher missing pattern" {
  let src =
    #|{ "hooks": [ { "match": {}, "action": { "type": "exec", "run": ["x"] } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].match: missing required field \"pattern\"",
  )
}

///|
test "matcher flags must be a string" {
  let src =
    #|{ "hooks": [ { "match": { "pattern": "a", "flags": 1 }, "action": { "type": "exec", "run": ["x"] } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].match.flags: expected a string",
  )
}

///|
test "all missing required fields are reported at once" {
  let src =
    #|{ "hooks": [ { "action": { "type": "replace" } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action: missing required field \"pattern\"\nconfig.hooks[0].action: missing required field \"with\"",
  )
}

///|
test "errors across the whole document accumulate" {
  let src =
    #|{ "hooks": [
    #|  { "action": { "type": "replace", "pattern": 1, "with": 2 } },
    #|  { "match": { "pattern": "ok" } }
    #|] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.pattern: expected a string\nconfig.hooks[0].action.with: expected a string\nconfig.hooks[1]: missing required field \"action\"",
  )
}

///|
test "multiple unknown fields are all reported" {
  let src =
    #|{ "hooks": [ { "action": { "type": "exec", "run": ["x"] }, "foo": 1, "bar": 2 } ] }
  let msg = decode_err(src)
  @test.assert_eq(msg.contains("config.hooks[0]: unknown field \"foo\""), true)
  @test.assert_eq(msg.contains("config.hooks[0]: unknown field \"bar\""), true)
}

///|
test "unknown field and missing action reported together" {
  let src =
    #|{ "hooks": [ { "foo": 1 } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0]: unknown field \"foo\"\nconfig.hooks[0]: missing required field \"action\"",
  )
}

///|
test "matcher with unknown field" {
  let src =
    #|{ "hooks": [ { "match": { "pattern": "a", "extra": 1 }, "action": { "type": "exec", "run": ["x"] } } ] }
  @test.assert_eq(decode_err(src), "config.hooks[0].match: unknown field \"extra\"")
}

///|
test "invalid JSON is a parse error, not a ConfigError" {
  let other = try {
    parse("{ not valid") |> ignore
    false
  } catch {
    ConfigError(_) => abort("malformed JSON must not surface as ConfigError")
    _ => true
  }
  @test.assert_eq(other, true)
}

///|
test "exec with all fields" {
  let src =
    #|{ "hooks": [ { "action":
    #|  { "type": "exec", "run": ["sh", "-c", "x"], "timeout_ms": 500, "on_error": "abort" } } ] }
  let cfg = parse(src)
  @test.assert_eq(
    cfg.hooks[0].action,
    Exec(run=["sh", "-c", "x"], timeout_ms=Some(500), on_error=Abort),
  )
}

///|
test "timeout_ms = 0 is accepted (minimum boundary)" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": ["x"], "timeout_ms": 0 } } ] }
  let cfg = parse(src)
  @test.assert_eq(
    cfg.hooks[0].action,
    Pipe(run=["x"], timeout_ms=Some(0), on_error=Skip),
  )
}

///|
test "action must be an object" {
  let src =
    #|{ "hooks": [ { "action": 1 } ] }
  @test.assert_eq(decode_err(src), "config.hooks[0].action: expected an object")
}

///|
test "match must be an object" {
  let src =
    #|{ "hooks": [ { "match": 1, "action": { "type": "exec", "run": ["x"] } } ] }
  @test.assert_eq(decode_err(src), "config.hooks[0].match: expected an object")
}

///|
test "replace with must be a string" {
  let src =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "a", "with": 1 } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.with: expected a string",
  )
}

///|
test "replace flags must be a string" {
  let src =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "a", "with": "b", "flags": 1 } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.flags: expected a string",
  )
}

///|
test "on_error must be a string" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": ["x"], "on_error": 1 } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.on_error: expected a string",
  )
}

///|
test "array accumulates errors from every bad element" {
  let src =
    #|{ "hooks": [ { "action": { "type": "pipe", "run": [1, 2] } } ] }
  @test.assert_eq(
    decode_err(src),
    "config.hooks[0].action.run[0]: expected a string\nconfig.hooks[0].action.run[1]: expected a string",
  )
}

///|
test "schema_json is well-formed JSON" {
  @json.parse(schema_json()) |> ignore
}

///|
test "schema top-level shape" {
  let s = schema()
  assert_json(get_key(s, "type"), "object".to_json())
  assert_json(get_key(s, "additionalProperties"), false.to_json())
  assert_json(get_key(s, "required"), ["hooks"].to_json())
  assert_json(
    get_key(s, "$schema"),
    "http://json-schema.org/draft-07/schema#".to_json(),
  )
}

///|
test "hooks is an array of hook objects requiring action" {
  let hooks = get_key(get_key(schema(), "properties"), "hooks")
  assert_json(get_key(hooks, "type"), "array".to_json())
  let hook = get_key(hooks, "items")
  assert_json(get_key(hook, "required"), ["action"].to_json())
  let hook_props = get_key(hook, "properties")
  assert_json(get_key(get_key(hook_props, "name"), "type"), "string".to_json())
}

///|
test "action schema is a oneOf of replace/pipe/exec" {
  let hook = get_key(get_key(get_key(schema(), "properties"), "hooks"), "items")
  let action = get_key(get_key(hook, "properties"), "action")
  guard get_key(action, "oneOf") is Array(variants) else {
    abort("oneOf must be an array")
  }
  @test.assert_eq(variants.length(), 3)
  let replace = variants[0]
  assert_json(
    get_key(replace, "required"),
    ["type", "pattern", "with"].to_json(),
  )
  assert_json(get_key(replace, "additionalProperties"), false.to_json())
  assert_json(
    get_key(get_key(get_key(replace, "properties"), "type"), "const"),
    "replace".to_json(),
  )
  assert_json(
    get_key(get_key(get_key(replace, "properties"), "flags"), "type"),
    "string".to_json(),
  )
  let pipe = variants[1]
  let run = get_key(get_key(pipe, "properties"), "run")
  assert_json(get_key(run, "type"), "array".to_json())
  assert_json(get_key(run, "minItems"), (1).to_json())
  assert_json(
    get_key(get_key(get_key(pipe, "properties"), "timeout_ms"), "minimum"),
    (0).to_json(),
  )
  assert_json(
    get_key(get_key(get_key(pipe, "properties"), "on_error"), "enum"),
    ["skip", "abort"].to_json(),
  )
  let exec = variants[2]
  assert_json(
    get_key(get_key(get_key(exec, "properties"), "type"), "const"),
    "exec".to_json(),
  )
  assert_json(
    get_key(get_key(get_key(exec, "properties"), "run"), "minItems"),
    (1).to_json(),
  )
  assert_json(
    get_key(get_key(get_key(exec, "properties"), "on_error"), "enum"),
    ["skip", "abort"].to_json(),
  )
}

///|
test "match property is the matcher schema" {
  let hook = get_key(get_key(get_key(schema(), "properties"), "hooks"), "items")
  let m = get_key(get_key(hook, "properties"), "match")
  assert_json(get_key(m, "type"), "object".to_json())
  assert_json(get_key(m, "required"), ["pattern"].to_json())
  assert_json(
    get_key(get_key(get_key(m, "properties"), "pattern"), "type"),
    "string".to_json(),
  )
  assert_json(
    get_key(get_key(get_key(m, "properties"), "flags"), "type"),
    "string".to_json(),
  )
}

///|
test "log_level property is an enum and stays optional" {
  let props = get_key(schema(), "properties")
  assert_json(
    get_key(get_key(props, "log_level"), "enum"),
    ["debug", "info", "warn"].to_json(),
  )
  assert_json(get_key(schema(), "required"), ["hooks"].to_json())
}
