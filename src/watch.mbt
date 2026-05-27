///|
async fn decide(
  last_written : String?,
  text : String,
  compiled : @engine.Compiled,
) -> String? {
  if last_written == Some(text) {
    None
  } else {
    let result = compiled.run(text)
    if result == text {
      None
    } else {
      Some(result)
    }
  }
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
  log_debug("clipboard changed; applying hooks")
  let result = decide(last_written.val, text, compiled) catch {
    e => {
      log_warn("hook failed: \{error_message(e)}")
      None
    }
  }
  match result {
    Some(r) =>
      // Don't clobber a copy the user made while a slow hook was running.
      try {
        if clipboard.get_text() == text {
          clipboard.set_text(r)
          last_written.val = Some(r)
        } else {
          log_debug("clipboard changed during processing; skipping writeback")
        }
      } catch {
        e => log_warn("write failed: \{error_message(e)}")
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
async fn watch(config : String?) -> Unit {
  let compiled = load_compiled(config)
  log_notices(compiled.notices()[:])
  @signal.set_global_cancellation_signals([@signal.SIGINT, @signal.SIGTERM])
  log_info("watching clipboard (Ctrl-C to stop)")
  @async.with_task_group(group => {
    let clipboard = @clipboard.Clipboard::new()
    let last_written : Ref[String?] = { val: None }
    let pending : Ref[String?] = { val: None }
    let running : Ref[Bool] = { val: false }
    clipboard.watch(group, text => {
      pending.val = Some(text)
      if !running.val {
        running.val = true
        group.spawn_bg(() => {
          drain(clipboard, compiled, last_written, pending, running)
        })
      }
    })
    |> ignore
  }) catch {
    e =>
      if @async.is_cancellation_error(e) {
        log_info("stopped")
      } else {
        raise e
      }
  }
}
