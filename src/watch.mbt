///|
async fn decide(
  last_written : String?,
  text : String,
  compiled : @engine.Compiled,
) -> String? raise {
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
  compiled.notices().each((n) => println("cbhook: notice: \{n}"))
  println("cbhook: config is valid")
}

///|
fn take_pending(pending : Ref[String?]) -> String? {
  let next = pending.val
  pending.val = None
  next
}

///|
async fn run_pipeline(
  clipboard : @clipboard.Clipboard,
  compiled : @engine.Compiled,
  last_written : Ref[String?],
  text : String,
) -> Unit {
  let result = try decide(last_written.val, text, compiled) catch {
    e => {
      println("cbhook: hook failed: \{error_message(e)}")
      None
    }
  }
  match result {
    Some(r) => {
      last_written.val = Some(r)
      try clipboard.set_text(r) catch {
        e => println("cbhook: write failed: \{error_message(e)}")
      }
    }
    None => ()
  }
}

// Single-flight, latest-wins. The callback's set-pending/check-running and
// drain's read-pending/clear-running are await-free, so they never interleave.
///|
async fn drain(
  clipboard : @clipboard.Clipboard,
  compiled : @engine.Compiled,
  last_written : Ref[String?],
  pending : Ref[String?],
  running : Ref[Bool],
) -> Unit {
  match take_pending(pending) {
    None => running.val = false
    Some(text) => {
      run_pipeline(clipboard, compiled, last_written, text)
      drain(clipboard, compiled, last_written, pending, running)
    }
  }
}

///|
async fn watch(config : String?) -> Unit raise {
  let compiled = load_compiled(config)
  compiled.notices().each((n) => println("cbhook: notice: \{n}"))
  @async.with_task_group(group => {
    let clipboard = @clipboard.Clipboard::new()
    let last_written : Ref[String?] = { val: None }
    let pending : Ref[String?] = { val: None }
    let running : Ref[Bool] = { val: false }
    println("cbhook: watching clipboard (Ctrl-C to stop)")
    clipboard.watch(group, (text) => {
      pending.val = Some(text)
      if !running.val {
        running.val = true
        group.spawn_bg(() => drain(
          clipboard,
          compiled,
          last_written,
          pending,
          running,
        ))
      }
    })
    |> ignore
  })
}
