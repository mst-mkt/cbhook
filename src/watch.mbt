///|
fn decide(
  last_written : String?,
  text : String,
  compiled : @engine.Compiled,
) -> String? {
  if last_written == Some(text) {
    None
  } else {
    let result = @engine.run(compiled, text)
    if result == text {
      None
    } else {
      Some(result)
    }
  }
}

///|
async fn load_compiled(config : String?) -> @engine.Compiled raise {
  let path = match discover_config_path(config) {
    Some(p) => p
    None =>
      raise @config.ConfigError(
        "no config found (use --config, $CBHOOK_CONFIG, or ~/.config/cbhook/config.json)",
      )
  }
  let source = try @fs.read_file(path).text() catch {
    _ => raise @config.ConfigError("cannot read config file: \{path}")
  }
  @engine.compile(@config.parse(source))
}

///|
async fn check(config : String?) -> Unit raise {
  let compiled = load_compiled(config)
  compiled.notices.each((n) => println("cbhook: notice: \{n}"))
  println("cbhook: config is valid")
}

///|
async fn watch(config : String?) -> Unit raise {
  let compiled = load_compiled(config)
  compiled.notices.each((n) => println("cbhook: notice: \{n}"))
  @async.with_task_group(group => {
    let clipboard = @clipboard.Clipboard::new()
    let last_written : Ref[String?] = { val: None }
    println("cbhook: watching clipboard (Ctrl-C to stop)")
    clipboard.watch(group, (text) => match decide(
        last_written.val,
        text,
        compiled,
      ) {
      Some(result) => {
        last_written.val = Some(result)
        group.spawn_bg(() => try clipboard.set_text(result) catch {
          e => println("cbhook: write failed: \{error_message(e)}")
        })
      }
      None => ()
    })
    |> ignore
  })
}
