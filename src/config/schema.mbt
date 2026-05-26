///|
fn on_error_schema() -> Schema[OnError] {
  enum_schema(["skip", "abort"], s => match s {
    "skip" => Some(Skip)
    "abort" => Some(Abort)
    _ => None
  })
}

///|
fn matcher_schema() -> Schema[Matcher] {
  pure(fn(pattern) { fn(flags) { Matcher::{ pattern, flags } } })
  .apply(required_field("pattern", string_schema()))
  .apply(optional_field("flags", string_schema()))
  .build()
}

///|
fn action_schema() -> Schema[Action] {
  tagged("type", [
    (
      "replace",
      pure(fn(_t) {
        fn(pattern) {
          fn(replacement) { fn(flags) { Replace(pattern~, replacement~, flags~) } }
        }
      })
      .apply(const_field("type", "replace"))
      .apply(required_field("pattern", string_schema()))
      .apply(required_field("with", string_schema()))
      .apply(optional_field("flags", string_schema()))
      .build(),
    ),
    (
      "pipe",
      pure(fn(_t) {
        fn(run) {
          fn(timeout_ms) {
            fn(on_error : OnError?) {
              Pipe(run~, timeout_ms~, on_error=on_error.unwrap_or(Skip))
            }
          }
        }
      })
      .apply(const_field("type", "pipe"))
      .apply(required_field("run", array_schema(string_schema(), min_items=1)))
      .apply(optional_field("timeout_ms", int_schema(minimum=0)))
      .apply(optional_field("on_error", on_error_schema()))
      .build(),
    ),
    (
      "exec",
      pure(fn(_t) {
        fn(run) {
          fn(timeout_ms) {
            fn(on_error : OnError?) {
              Exec(run~, timeout_ms~, on_error=on_error.unwrap_or(Skip))
            }
          }
        }
      })
      .apply(const_field("type", "exec"))
      .apply(required_field("run", array_schema(string_schema(), min_items=1)))
      .apply(optional_field("timeout_ms", int_schema(minimum=0)))
      .apply(optional_field("on_error", on_error_schema()))
      .build(),
    ),
  ])
}

///|
fn hook_schema() -> Schema[Hook] {
  pure(fn(name) {
    fn(matcher) { fn(action) { Hook::{ name, matcher, action } } }
  })
  .apply(optional_field("name", string_schema()))
  .apply(optional_field("match", matcher_schema()))
  .apply(required_field("action", action_schema()))
  .build()
}

///|
fn log_level_schema() -> Schema[LogLevel] {
  enum_schema(["debug", "info", "warn"], s => match s {
    "debug" => Some(Debug)
    "info" => Some(Info)
    "warn" => Some(Warn)
    _ => None
  })
}

///|
fn config_schema() -> Schema[Config] {
  pure(fn(hooks) { fn(log_level) { Config::{ hooks, log_level } } })
  .apply(required_field("hooks", array_schema(hook_schema())))
  .apply(optional_field("log_level", log_level_schema()))
  .build()
}

///|
pub fn parse(source : String) -> Config raise {
  from_json(@json.parse(source))
}

///|
fn from_json(json : Json) -> Config raise ConfigError {
  match (config_schema().decode)(json, "config") {
    Ok(c) => c
    Err(es) => raise ConfigError(join_with(es, "\n"))
  }
}

///|
fn schema() -> Json {
  let base = (config_schema().to_schema)()
  guard base is Object(m) else { return base }
  let meta : Array[(String, Json)] = [
    ("$schema", "http://json-schema.org/draft-07/schema#".to_json()),
    ("title", "cbhook configuration".to_json()),
  ]
  jobj(m.iter().fold(init=meta, fn(acc, kv) { [..acc, kv] }))
}

///|
pub fn schema_json() -> String {
  schema().stringify(indent=2)
}
